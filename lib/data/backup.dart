import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'active_workout.dart';
import 'app_state.dart';
import 'reset.dart';

/// Marks a file as a FitStreak backup.
const _backupApp = 'fitstreak';

/// Format of the backup file, raised if it ever changes incompatibly.
const _backupVersion = 1;

/// Keys left out of a backup: the motivation picture is a file path that
/// won't exist on another install.
const _skippedKeys = {'motivation_image'};

/// Encodes every preference (profile, routine, streak, history, settings and
/// the online session) as a backup JSON string.
String encodeBackup(SharedPreferences prefs, {DateTime? now}) {
  final values = <String, Object>{};
  for (final key in prefs.getKeys()) {
    if (_skippedKeys.contains(key)) continue;
    final value = prefs.get(key);
    if (value != null) values[key] = value;
  }
  return jsonEncode({
    'app': _backupApp,
    'version': _backupVersion,
    'createdAt': (now ?? DateTime.now()).toIso8601String(),
    'prefs': values,
  });
}

/// Reads the preferences stored in backup [json].
///
/// Throws a [FormatException] if [json] is not a FitStreak backup.
Map<String, Object?> parseBackup(String json) {
  final data = jsonDecode(json);
  if (data is! Map || data['app'] != _backupApp || data['prefs'] is! Map) {
    throw const FormatException('No es una copia de FitStreak');
  }
  if ((data['version'] as num? ?? 0) > _backupVersion) {
    throw const FormatException('Copia de una versión más nueva de FitStreak');
  }
  return (data['prefs'] as Map).cast<String, Object?>();
}

/// Replaces every preference with [values] from [parseBackup].
Future<void> restoreBackup(SharedPreferences prefs, Map<String, Object?> values) async {
  await prefs.clear();
  for (final MapEntry(:key, :value) in values.entries) {
    switch (value) {
      case bool v:
        await prefs.setBool(key, v);
      case int v:
        await prefs.setInt(key, v);
      case double v:
        await prefs.setDouble(key, v);
      case String v:
        await prefs.setString(key, v);
      case List v:
        await prefs.setStringList(key, v.cast<String>());
    }
  }
}

/// Writes a backup file and opens the share sheet so the user saves it
/// (Drive, Files, WhatsApp to themselves…).
Future<void> shareBackup(WidgetRef ref) async {
  final json = encodeBackup(ref.read(prefsProvider));
  final dir = await getTemporaryDirectory();
  final day = DateTime.now().toIso8601String().substring(0, 10);
  final file = File('${dir.path}/fitstreak-copia-$day.json');
  await file.writeAsString(json);
  await SharePlus.instance.share(ShareParams(
    subject: 'Copia de FitStreak',
    text: 'Copia de seguridad de FitStreak ($day)',
    files: [XFile(file.path, mimeType: 'application/json')],
  ));
}

/// Lets the user pick a backup file, replaces all data with it and restarts
/// the app. Shows a message if the file can't be used.
Future<void> pickAndRestoreBackup(BuildContext context, WidgetRef ref) async {
  try {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return;
    final values = parseBackup(utf8.decode(await file.readAsBytes()));
    // Validated: now the current data can go.
    ref.read(activeWorkoutProvider.notifier).abandon();
    await restoreBackup(ref.read(prefsProvider), values);
  } catch (e) {
    debugPrint('No se pudo restaurar la copia: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ese archivo no es una copia de FitStreak.'),
      ));
    }
    return;
  }
  if (context.mounted) AppRestarter.restart(context);
}
