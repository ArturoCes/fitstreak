import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'exercise.dart';
import 'exercise_repository.dart';
import 'routine.dart';

/// Prefix of the code used to pass a routine to someone over WhatsApp,
/// Telegram...: the routine as compressed JSON in base64. It also carries the
/// custom exercises, which don't exist on the other phone.
const sharePrefix = 'FITSTREAK1:';

/// A routine received from someone else, with its custom exercises.
class SharedRoutine {
  /// Creates a shared routine.
  const SharedRoutine(this.routine, this.customExercises);

  /// The routine.
  final Routine routine;

  /// Custom exercises it uses.
  final List<Exercise> customExercises;
}

/// The routine and its custom exercises as JSON: what goes inside the code
/// and what is stored in Supabase when it is published.
Map<String, dynamic> sharePayload(Routine routine, List<Exercise> allExercises) {
  final used = {
    for (final d in routine.days)
      for (final i in d.items) ...[i.exerciseId, for (final a in i.alternatives) a.exerciseId],
  };
  return {
    'routine': routine.toJson(),
    'custom': [
      for (final e in allExercises)
        if (isCustomExercise(e.id) && used.contains(e.id))
          {'id': e.id, 'name': e.name, 'equipment': e.equipment},
    ],
  };
}

/// The inverse of [sharePayload]. Throws if the JSON is not a routine.
SharedRoutine sharedFromPayload(Map<String, dynamic> json) => SharedRoutine(
      Routine.fromJson(json['routine'] as Map<String, dynamic>),
      [
        for (final c in json['custom'] as List? ?? const [])
          customExercise(
            id: c['id'] as String,
            name: c['name'] as String,
            equipment: c['equipment'] as String? ?? 'machine',
          ),
      ],
    );

/// The share code of [routine] (`FITSTREAK1:` + gzip + base64url).
String encodeRoutine(Routine routine, List<Exercise> allExercises) {
  final zipped = GZipEncoder().encodeBytes(utf8.encode(jsonEncode(sharePayload(routine, allExercises))));
  return '$sharePrefix${base64Url.encode(zipped).replaceAll('=', '')}';
}

/// Finds a code inside [text] (it may come with the message around it).
/// Returns null when there is no code or it is broken.
SharedRoutine? decodeRoutine(String text) {
  final m = RegExp(RegExp.escape(sharePrefix) + r'([A-Za-z0-9_\-]+)').firstMatch(text);
  if (m == null) return null;
  try {
    var b64 = m[1]!;
    b64 = b64.padRight((b64.length + 3) ~/ 4 * 4, '=');
    return sharedFromPayload(jsonDecode(utf8.decode(GZipDecoder().decodeBytes(base64Url.decode(b64)))) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

/// Text of a .docx (Word, exported Google Docs...): one paragraph per line.
String docxToText(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final doc = archive.findFile('word/document.xml');
  if (doc == null) throw const FormatException('No parece un documento de Word');
  final xml = utf8.decode(doc.content, allowMalformed: true);
  return xml
      .replaceAll(RegExp(r'</w:p>'), '\n')
      .replaceAll(RegExp(r'<w:(br|cr)[^>]*/>'), '\n')
      .replaceAll(RegExp(r'<w:tab[^>]*/>'), '\t')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
