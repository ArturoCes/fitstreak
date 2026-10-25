import 'dart:math';

// Routines published in Supabase that other people follow.
//
// The author publishes a routine and gets a short code (FS-7K2QXM). Whoever
// pastes it in "Importar" follows it: on app start we check whether the
// author changed it and ask before replacing anything.

/// Characters of a routine code: no 0/O or 1/I, which get mixed up when
/// copied by hand.
const codeAlphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
/// Characters in a routine code.
const codeLength = 6;

/// Prefix shown before a code ("FS-7K2QXM").
const codePrefix = 'FS-';

/// A new random routine code (without prefix).
String newRoutineId([Random? random]) {
  final r = random ?? Random.secure();
  return String.fromCharCodes([
    for (var i = 0; i < codeLength; i++) codeAlphabet.codeUnitAt(r.nextInt(codeAlphabet.length)),
  ]);
}

/// The code as shown to people: "FS-" + [id].
String formatCode(String id) => '$codePrefix$id';

/// Link that opens the app and follows the routine (see supabase/functions/r).
String routineLink(String baseUrl, String id) => '$baseUrl/functions/v1/r/$id';

/// Finds an FS-XXXXXX code or a …/r/XXXXXX link inside [text] (with the
/// message around it, in lower case...). Returns the id without prefix, or
/// null.
String? parseRoutineCode(String text) {
  final m = RegExp(
    r'(?:(?<![A-Za-z0-9_])FS-|/functions/v1/r/|fitstreak://r/)([2-9A-HJ-NP-Z]{6})(?![A-Za-z0-9_])',
    caseSensitive: false,
  ).firstMatch(text);
  return m?[1]!.toUpperCase();
}

/// A routine as it is published.
class RemoteRoutine {
  /// Creates a published routine.
  const RemoteRoutine({
    required this.id,
    required this.author,
    required this.title,
    required this.payload,
    required this.version,
    required this.updatedAt,
    this.followers = 0,
    this.isPublic = false,
  });

  /// Routine code (without prefix).
  final String id;

  /// Author's display name.
  final String author;

  /// Routine title.
  final String title;

  /// The same as inside a FITSTREAK1 code (see sharePayload). Empty in
  /// search results: it is fetched later by code.
  final Map<String, dynamic> payload;

  /// Increases on every update by the author.
  final int version;

  /// Last update time.
  final DateTime updatedAt;

  /// How many people follow it.
  final int followers;

  /// Listed in the search. Only the owner sees it (false in other reads).
  final bool isPublic;

  /// Reads a row of the `routines` table or an RPC result.
  factory RemoteRoutine.fromJson(Map<String, dynamic> j) => RemoteRoutine(
        id: j['id'] as String,
        author: j['author'] as String,
        title: j['title'] as String,
        payload: (j['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        version: j['version'] as int,
        updatedAt: DateTime.parse(j['updated_at'] as String),
        followers: (j['followers'] as num?)?.toInt() ?? 0,
        isPublic: j['is_public'] as bool? ?? false,
      );
}

/// The routine this user published.
class Publication {
  /// Creates the publication record.
  const Publication({
    required this.id,
    required this.author,
    required this.version,
    required this.pushed,
    this.isPublic = false,
  });

  /// Routine code.
  final String id;

  /// Author name it was published under.
  final String author;

  /// Version on the server.
  final int version;

  /// Listed in the routine search (off by default: code only).
  final bool isPublic;

  /// JSON uploaded last time, to know whether there are unpublished changes.
  final String pushed;

  /// Copy with [isPublic] replaced.
  Publication copyWith({bool? isPublic}) =>
      Publication(id: id, author: author, version: version, pushed: pushed, isPublic: isPublic ?? this.isPublic);

  /// Serializes the record for preferences.
  Map<String, dynamic> toJson() =>
      {'id': id, 'author': author, 'version': version, 'pushed': pushed, if (isPublic) 'public': true};

  /// Reads a record written by [toJson].
  factory Publication.fromJson(Map<String, dynamic> j) => Publication(
        id: j['id'] as String,
        author: j['author'] as String,
        version: j['version'] as int,
        pushed: j['pushed'] as String,
        isPublic: j['public'] as bool? ?? false,
      );
}

/// Someone else's routine this user follows and uses as their own.
class Following {
  /// Creates the following record.
  const Following({
    required this.id,
    required this.author,
    required this.title,
    required this.version,
    this.dismissed,
  });

  /// Routine code.
  final String id;

  /// Author's name.
  final String author;

  /// Routine title.
  final String title;

  /// Version currently applied.
  final int version;

  /// Version the user declined: it isn't offered again.
  final int? dismissed;

  /// Copy with the given fields replaced.
  Following copyWith({String? author, String? title, int? version, int? dismissed}) => Following(
        id: id,
        author: author ?? this.author,
        title: title ?? this.title,
        version: version ?? this.version,
        dismissed: dismissed ?? this.dismissed,
      );

  /// Serializes the record for preferences.
  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'title': title,
        'version': version,
        if (dismissed != null) 'dismissed': dismissed,
      };

  /// Reads a record written by [toJson].
  factory Following.fromJson(Map<String, dynamic> j) => Following(
        id: j['id'] as String,
        author: j['author'] as String,
        title: j['title'] as String,
        version: j['version'] as int,
        dismissed: j['dismissed'] as int?,
      );
}

/// The published version if it is newer than the applied one and wasn't
/// declined; otherwise null.
RemoteRoutine? pendingUpdate(Following following, RemoteRoutine? remote) {
  if (remote == null || remote.id != following.id) return null;
  if (remote.version <= following.version) return null;
  if (following.dismissed != null && remote.version <= following.dismissed!) return null;
  return remote;
}

/// The code already exists (publishing retries with another one).
class CodeTakenException implements Exception {
  /// Creates the exception.
  const CodeTakenException();
}

/// What the app needs from the server. Tests replace it with an in-memory one.
abstract class RoutineSyncApi {
  /// Signs in anonymously if needed. Returns the user id.
  Future<String> ensureSignedIn();

  /// Creates the routine with that code. Throws [CodeTakenException] if it
  /// already exists.
  Future<RemoteRoutine> create({
    required String id,
    required String author,
    required String title,
    required Map<String, dynamic> payload,
  });

  /// Replaces the content of one of my routines and bumps its version.
  Future<RemoteRoutine> update({
    required String id,
    required String author,
    required String title,
    required Map<String, dynamic> payload,
  });

  /// Routines by code; missing ones are left out.
  Future<List<RemoteRoutine>> fetch(List<String> ids);

  /// Routines I published (to restore them after signing in with email).
  Future<List<RemoteRoutine>> mine();

  /// Public routines whose author or title contains [query] (without text,
  /// the most followed). Most followed first; at most 50. Without payload.
  Future<List<RemoteRoutine>> search(String query, {int limit = 20});

  /// Lists or unlists one of my routines in the search. Doesn't bump the
  /// version.
  Future<void> setPublic(String id, bool isPublic);

  /// Records that the current user follows routine [id].
  Future<void> follow(String id);

  /// Removes the current user from the followers of routine [id].
  Future<void> unfollow(String id);
}
