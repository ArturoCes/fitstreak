import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'exercise.dart';
import 'exercise_repository.dart';
import 'labels_es.dart';
import 'routine.dart';
import 'routine_generator.dart';
import 'user_profile.dart';

/// Local key-value storage. Overridden in `main()` with the loaded instance.
final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('prefsProvider sin inicializar'),
);

const _profileKey = 'profile';
const _routineKey = 'routine';

/// The user's profile (null until the onboarding is done).
class ProfileNotifier extends Notifier<UserProfile?> {
  /// Loads the saved profile.
  @override
  UserProfile? build() {
    final raw = ref.read(prefsProvider).getString(_profileKey);
    return raw == null ? null : UserProfile.fromJson(jsonDecode(raw));
  }

  /// Replaces and saves the profile.
  Future<void> save(UserProfile p) async {
    state = p;
    await ref.read(prefsProvider).setString(_profileKey, jsonEncode(p.toJson()));
  }
}

/// The user's profile.
final profileProvider = NotifierProvider<ProfileNotifier, UserProfile?>(
  ProfileNotifier.new,
);

/// The user's routine and every change to it (generate, import, swap,
/// alternatives). Each change is saved right away.
class RoutineNotifier extends Notifier<Routine?> {
  /// Loads the saved routine.
  @override
  Routine? build() {
    final raw = ref.read(prefsProvider).getString(_routineKey);
    return raw == null ? null : Routine.fromJson(jsonDecode(raw));
  }

  /// A generator for the current profile and catalog.
  Future<RoutineGenerator> generator() async {
    final all = await ref.read(exercisesProvider.future);
    return RoutineGenerator(ref.read(profileProvider)!, all);
  }

  /// Builds a fresh routine from the profile.
  Future<void> regenerate() async => _save((await generator()).generate());

  /// Uses a routine written by the user or received from someone else.
  Future<void> replaceWith(Routine r) => _save(r);

  /// Replaces item [item] of day [day] with exercise [exerciseId].
  Future<void> swap(int day, int item, String exerciseId) async {
    final gen = await generator();
    final r = state!;
    final old = r.days[day].items[item];
    await _save(_withItem(r, day, item, _swapped(r, old, gen.byId(exerciseId), exerciseId)));
  }

  /// Replaces every exercise of a day with another that works the same
  /// muscles, without repeating any within the day. Returns the previous
  /// routine so the change can be undone. Custom exercises (no muscles) stay.
  Future<Routine?> regenerateDay(int day, {Random? random}) async {
    final before = state;
    if (before == null) return null;
    final rnd = random ?? Random();
    final gen = await generator();
    final items = before.days[day].items;
    final used = {for (final i in items) i.exerciseId};
    final next = <RoutineItem>[];
    for (final item in items) {
      final current = gen.byId(item.exerciseId);
      final options = current == null
          ? const <Exercise>[]
          : [for (final e in gen.alternatives(current, limit: 8)) if (!used.contains(e.id)) e];
      if (options.isEmpty) {
        next.add(item);
        continue;
      }
      // Random among the best ones, so regenerating twice gives a new mix.
      final pick = options[rnd.nextInt(min(3, options.length))];
      used.add(pick.id);
      next.add(_swapped(before, item, pick, pick.id));
    }
    final d = before.days[day];
    await _save(Routine(
      title: before.title,
      notes: before.notes,
      days: [
        for (final (i, rd) in before.days.indexed)
          i == day ? RoutineDay(name: d.name, note: d.note, items: next) : rd,
      ],
    ));
    return before;
  }

  /// Adds "or [exerciseId]" to an item. Ignored when it is already the
  /// exercise or one of its options.
  Future<void> addOption(int day, int item, {required String exerciseId, required String slot}) async {
    final r = state!;
    final it = r.days[day].items[item];
    if (it.exerciseId == exerciseId || it.alternatives.any((a) => a.exerciseId == exerciseId)) return;
    await _save(_withItem(r, day, item, it.withAlternatives([...it.alternatives, ExerciseOption(exerciseId: exerciseId, slot: slot)])));
  }

  /// Removes option [option] from an item.
  Future<void> removeOption(int day, int item, int option) async {
    final r = state!;
    final it = r.days[day].items[item];
    await _save(_withItem(r, day, item, it.withAlternatives([...it.alternatives]..removeAt(option))));
  }

  /// "Dips or triceps pushdown": switches the item to option [option].
  Future<void> chooseOption(int day, int item, int option) async {
    final r = state!;
    await _save(_withItem(r, day, item, r.days[day].items[item].choose(option)));
  }

  /// [old] doing [id] instead. In an imported routine the label is the name
  /// the user wrote ("Press banca"): when the exercise changes it becomes the
  /// muscle, and the comment ("ligero") no longer applies.
  RoutineItem _swapped(Routine r, RoutineItem old, Exercise? e, String id) {
    if (r.title == null || e == null || e.primaryMuscles.isEmpty) return old.withExercise(id);
    return RoutineItem(
      exerciseId: id,
      slot: _capitalize(es(muscleEs, e.primaryMuscles.first)),
      sets: old.sets,
      reps: old.reps,
      restSeconds: old.restSeconds,
      alternatives: old.alternatives,
    );
  }

  /// [s] with its first letter in upper case.
  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// [r] with item [index] of day [day] replaced by [item].
  static Routine _withItem(Routine r, int day, int index, RoutineItem item) => Routine(
        title: r.title,
        notes: r.notes,
        days: [
          for (final (d, rd) in r.days.indexed)
            d != day
                ? rd
                : RoutineDay(
                    name: rd.name,
                    note: rd.note,
                    items: [for (final (i, it) in rd.items.indexed) i == index ? item : it],
                  ),
        ],
      );

  /// "I don't have this": never suggest it again and swap it for the best
  /// alternative.
  Future<void> block(int day, int item) async {
    final id = state!.days[day].items[item].exerciseId;
    final profiles = ref.read(profileProvider.notifier);
    final p = ref.read(profileProvider)!;
    await profiles.save(p.copyWith(blockedExercises: {...p.blockedExercises, id}));

    final gen = await generator();
    final current = gen.byId(id);
    final alt = current == null ? const [] : gen.alternatives(current, limit: 1);
    if (alt.isNotEmpty) await swap(day, item, alt.first.id);
  }

  /// Applies and saves [r].
  Future<void> _save(Routine r) async {
    state = r;
    await ref.read(prefsProvider).setString(_routineKey, jsonEncode(r.toJson()));
  }
}

/// The user's routine (null before the onboarding).
final routineProvider = NotifierProvider<RoutineNotifier, Routine?>(
  RoutineNotifier.new,
);
