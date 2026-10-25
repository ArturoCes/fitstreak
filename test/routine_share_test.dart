import 'package:archive/archive.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fitstreak/data/exercise_repository.dart';
import 'package:fitstreak/data/routine.dart';
import 'package:fitstreak/data/routine_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final custom = customExercise(id: 'custom-curl-bayesian', name: 'Curl bayesian', equipment: 'cable');
  const routine = Routine(
    title: 'Push Pull Pierna',
    notes: ['Descansos\n• Grandes → 2–3 min'],
    days: [
      RoutineDay(name: 'Push', note: 'Solo activación', items: [
        RoutineItem(exerciseId: 'Barbell_Bench_Press_-_Medium_Grip', slot: 'Press banca', sets: 4, reps: '6-10', restSeconds: 150),
        RoutineItem(exerciseId: 'custom-curl-bayesian', slot: 'Curl bayesian', sets: 3, reps: '10-12', restSeconds: 75, note: 'Brazos atrás'),
      ]),
    ],
  );

  test('el código lleva la rutina entera y los ejercicios propios', () {
    final code = encodeRoutine(routine, [custom]);
    expect(code, startsWith(sharePrefix));
    // Viene dentro de un mensaje de WhatsApp con texto alrededor.
    final back = decodeRoutine('Te paso mi rutina 💪\n\n$code\n\nUn saludo')!;
    expect(back.routine.title, 'Push Pull Pierna');
    expect(back.routine.notes, routine.notes);
    expect(back.routine.days.single.note, 'Solo activación');
    final items = back.routine.days.single.items;
    expect((items[0].slot, items[0].sets, items[0].reps, items[0].restSeconds), ('Press banca', 4, '6-10', 150));
    expect(items[1].note, 'Brazos atrás');
    expect(back.customExercises.single.name, 'Curl bayesian');
    expect(back.customExercises.single.equipment, 'cable');
  });

  test('un código cortado o inventado no rompe nada', () {
    final code = encodeRoutine(routine, [custom]);
    expect(decodeRoutine(code.substring(0, code.length ~/ 2)), isNull);
    expect(decodeRoutine('${sharePrefix}hola'), isNull);
    expect(decodeRoutine('sin código'), isNull);
  });

  test('lee el texto de un .docx', () {
    const xml = '<w:document><w:body>'
        '<w:p><w:r><w:t>DÍA 1 – PUSH</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Press banca → 4x6–10 &amp; más</w:t></w:r></w:p>'
        '</w:body></w:document>';
    final zip = ZipEncoder().encodeBytes(Archive()..add(ArchiveFile.bytes('word/document.xml', utf8.encode(xml))));
    final text = docxToText(Uint8List.fromList(zip));
    expect(text.trim().split('\n'), ['DÍA 1 – PUSH', 'Press banca → 4x6–10 & más']);
  });
}
