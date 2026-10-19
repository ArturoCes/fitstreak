import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final exercises = jsonDecode(File('assets/data/exercises.json').readAsStringSync()) as List;
  final es = (jsonDecode(File('assets/data/instructions_es.json').readAsStringSync())
          as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, (v as List).cast<String>()));

  test('todos los ejercicios con instrucciones tienen traducción', () {
    final missing = [
      for (final e in exercises)
        if ((e['instructions'] as List).isNotEmpty && !es.containsKey(e['id'])) e['id'],
    ];
    expect(missing, isEmpty);
  });

  test('cada traducción tiene los mismos pasos que el original', () {
    for (final e in exercises) {
      final translated = es[e['id']];
      if (translated == null) continue;
      expect(translated.length, (e['instructions'] as List).length, reason: e['id'] as String);
    }
  });

  test('no quedan restos en inglés típicos', () {
    final leftovers = RegExp(r'\b(This will be your starting position|Repeat for the recommended|breathe out|Tip:)\b');
    for (final MapEntry(:key, :value) in es.entries) {
      for (final step in value) {
        expect(leftovers.hasMatch(step), isFalse, reason: '$key: $step');
      }
    }
  });
}
