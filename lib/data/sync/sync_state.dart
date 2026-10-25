import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_state.dart';
import '../exercise.dart';
import '../exercise_repository.dart';
import '../routine.dart';
import '../routine_share.dart';
import 'routine_sync.dart';
import 'supabase_sync_api.dart';

/// The server API. Tests replace it with an in-memory one.
final routineSyncApiProvider = Provider<RoutineSyncApi>(
  (_) => SupabaseRoutineSyncApi(Supabase.instance.client),
);

const _publishedKey = 'sync_published';
const _followingKey = 'sync_following';

/// What this user published and which routine they follow.
class SyncState {
  /// Creates the state.
  const SyncState({this.published, this.following});

  /// The routine I published (null if none).
  final Publication? published;

  /// The routine I follow (null if none).
  final Following? following;
}

/// Publishing, following and updating shared routines.
class SyncNotifier extends Notifier<SyncState> {
  /// Loads the saved publication and following records.
  @override
  SyncState build() {
    final prefs = ref.read(prefsProvider);
    Map<String, dynamic>? read(String key) {
      final raw = prefs.getString(key);
      return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    }

    return SyncState(
      published: read(_publishedKey)?.let(Publication.fromJson),
      following: read(_followingKey)?.let(Following.fromJson),
    );
  }

  /// The server API.
  RoutineSyncApi get _api => ref.read(routineSyncApiProvider);

  /// The JSON that would be published right now.
  static String payloadJson(Routine routine, List<Exercise> exercises) =>
      jsonEncode(sharePayload(routine, exercises));

  /// Whether my routine changed since the last upload.
  bool hasUnpushedChanges(Routine? routine, List<Exercise> exercises) {
    final p = state.published;
    return p != null && routine != null && payloadJson(routine, exercises) != p.pushed;
  }

  /// Publishes my routine (the first time it creates the code; afterwards it
  /// updates it).
  Future<Publication> publish({required String author, Random? random}) async {
    final routine = ref.read(routineProvider)!;
    final exercises = await ref.read(exercisesProvider.future);
    final payload = sharePayload(routine, exercises);
    final title = routine.title ?? 'Rutina de $author';
    final current = state.published;

    RemoteRoutine remote;
    if (current != null) {
      remote = await _api.update(id: current.id, author: author, title: title, payload: payload);
    } else {
      var attempt = 0;
      while (true) {
        try {
          remote = await _api.create(id: newRoutineId(random), author: author, title: title, payload: payload);
          break;
        } on CodeTakenException {
          if (++attempt >= 5) rethrow;
        }
      }
    }
    final p = Publication(
      id: remote.id,
      author: author,
      version: remote.version,
      pushed: jsonEncode(payload),
      isPublic: current?.isPublic ?? false,
    );
    await _setPublished(p);
    return p;
  }

  /// Stops updating the publication from this phone (the routine stays on
  /// the server for its followers).
  Future<void> forgetPublication() => _setPublished(null);

  /// After signing in with email on another phone: restores my published
  /// routine.
  Future<RemoteRoutine?> restorePublication() async {
    final mine = await _api.mine();
    if (mine.isEmpty) return null;
    final r = mine.first;
    await _setPublished(Publication(
      id: r.id,
      author: r.author,
      version: r.version,
      pushed: jsonEncode(r.payload),
      isPublic: r.isPublic,
    ));
    return r;
  }

  /// Lists or unlists my published routine in the search.
  Future<void> setPublic(bool isPublic) async {
    final p = state.published;
    if (p == null) return;
    await _api.setPublic(p.id, isPublic);
    await _setPublished(p.copyWith(isPublic: isPublic));
  }

  /// Routines their authors listed in the search.
  Future<List<RemoteRoutine>> search(String query) => _api.search(query);

  /// The published routine with code [id], or null.
  Future<RemoteRoutine?> lookup(String id) async => (await _api.fetch([id])).firstOrNull;

  /// Starts following a routine that was already saved as mine.
  Future<void> startFollowing(RemoteRoutine r) async {
    final previous = state.following;
    if (r.id == state.published?.id) {
      // It's mine: there's nothing to follow.
      await stopFollowing();
      return;
    }
    await _setFollowing(Following(id: r.id, author: r.author, title: r.title, version: r.version));
    if (previous != null && previous.id != r.id) await _quietly(() => _api.unfollow(previous.id));
    await _quietly(() => _api.follow(r.id));
  }

  /// Stops following the current routine (it stays as my routine).
  Future<void> stopFollowing() async {
    final f = state.following;
    if (f == null) return;
    await _setFollowing(null);
    await _quietly(() => _api.unfollow(f.id));
  }

  /// The new version of the routine I follow, if any and not declined.
  Future<RemoteRoutine?> checkForUpdate() async {
    final f = state.following;
    if (f == null) return null;
    return pendingUpdate(f, await lookup(f.id));
  }

  /// Applies the new version as my routine. History, charts and streak are
  /// untouched: they are stored apart from the routine.
  Future<void> applyUpdate(RemoteRoutine r) async {
    final shared = sharedFromPayload(r.payload);
    await saveCustomExercises(ref.read(prefsProvider), shared.customExercises);
    ref.invalidate(exercisesProvider);
    await ref.read(routineProvider.notifier).replaceWith(shared.routine);
    final profile = ref.read(profileProvider);
    if (profile != null) {
      await ref
          .read(profileProvider.notifier)
          .save(profile.copyWith(daysPerWeek: shared.routine.days.length.clamp(2, 6)));
    }
    final f = state.following;
    if (f != null && f.id == r.id) {
      await _setFollowing(f.copyWith(author: r.author, title: r.title, version: r.version));
    }
  }

  /// "Not now": don't ask about this version again.
  Future<void> dismiss(RemoteRoutine r) async {
    final f = state.following;
    if (f == null || f.id != r.id) return;
    await _setFollowing(f.copyWith(dismissed: r.version));
  }

  /// Applies and saves the publication record.
  Future<void> _setPublished(Publication? p) async {
    state = SyncState(published: p, following: state.following);
    final prefs = ref.read(prefsProvider);
    p == null ? await prefs.remove(_publishedKey) : await prefs.setString(_publishedKey, jsonEncode(p.toJson()));
  }

  /// Applies and saves the following record.
  Future<void> _setFollowing(Following? f) async {
    state = SyncState(published: state.published, following: f);
    final prefs = ref.read(prefsProvider);
    f == null ? await prefs.remove(_followingKey) : await prefs.setString(_followingKey, jsonEncode(f.toJson()));
  }

  /// Runs [f] ignoring errors: the followers list is only for counting, so a
  /// failure doesn't matter.
  static Future<void> _quietly(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {}
  }
}

/// Publishing and following state.
final syncProvider = NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

/// Kotlin-style `let`, to map a nullable value inline.
extension _Let<T> on T {
  /// Calls [f] with this value.
  R let<R>(R Function(T) f) => f(this);
}
