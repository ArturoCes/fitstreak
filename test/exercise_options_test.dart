import 'dart:convert';
import 'dart:io';

import 'package:fitstreak/data/exercise.dart';
import 'package:fitstreak/data/exercise_repository.dart';
import 'package:fitstreak/data/routine.dart';
import 'package:fitstreak/data/routine_import.dart';
import 'package:fitstreak/data/routine_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('«A o B» al importar: el primero es el que toca y el otro queda de alternativa', () {
    final r = parseRoutineText('''
DÍA 1 – PUSH
* Press banca → 4x6–10
* Fondos o jalón de tríceps en polea → 3x8–12
* Fondos cerrados / jalón de tríceps en polea → 3x8–12
* Curl barra recta (ligero) → 3x10–12
''');
    final items = r.days.single.items;
    expect(items[0].alternatives, isEmpty);
    expect(items[1].name, 'Fondos');
    expect(items[1].alternatives, ['Jalón de tríceps en polea']);
    expect((items[1].sets, items[1].reps), (3, '8-12'));
    expect(items[2].name, 'Fondos cerrados');
    expect(items[2].alternatives, ['Jalón de tríceps en polea']);
    expect(items[3].alternatives, isEmpty);
    expect(items[3].note, 'Ligero');
  });

  test('una «o» suelta no parte el nombre', () {
    final r = parseRoutineText('DÍA 1\n* Remo en T o → 3x10\n* Press / → 3x10');
    expect(r.days.single.items.map((i) => i.alternatives), everyElement(isEmpty));
  });

  test('el jalón de tríceps se reconoce en el catálogo', () {
    final catalog = [
      for (final e in jsonDecode(File('assets/data/exercises.json').readAsStringSync()) as List)
        Exercise.fromJson(e as Map<String, dynamic>),
    ];
    expect(matchExercise('Jalón de tríceps en polea', catalog).exercise?.id, 'Triceps_Pushdown');
    expect(matchExercise('Fondos cerrados', catalog).exercise?.id, 'Dips_-_Triceps_Version');
  });

  const item = RoutineItem(
    exerciseId: 'Dips_-_Chest_Version',
    slot: 'Fondos',
    sets: 3,
    reps: '8-12',
    restSeconds: 150,
    note: 'Lento',
    alternatives: [ExerciseOption(exerciseId: 'Triceps_Pushdown', slot: 'Jalón de tríceps en polea')],
  );

  test('elegir la otra opción la intercambia, y volver a elegir deshace', () {
    final b = item.choose(0);
    expect((b.exerciseId, b.slot), ('Triceps_Pushdown', 'Jalón de tríceps en polea'));
    expect(b.alternatives.single.slot, 'Fondos');
    expect((b.sets, b.reps, b.restSeconds, b.note), (3, '8-12', 150, 'Lento'));
    final back = b.choose(0);
    expect((back.exerciseId, back.alternatives.single.exerciseId), ('Dips_-_Chest_Version', 'Triceps_Pushdown'));
  });

  test('las alternativas se guardan, se comparten y llevan sus ejercicios propios', () {
    final custom = customExercise(id: 'custom-jalon-cuerda', name: 'Jalón cuerda', equipment: 'cable');
    final routine = Routine(title: 'Mía', days: [
      RoutineDay(name: 'Push', items: [
        RoutineItem(
          exerciseId: item.exerciseId,
          slot: item.slot,
          sets: 3,
          reps: '8-12',
          restSeconds: 90,
          alternatives: [ExerciseOption(exerciseId: custom.id, slot: 'Jalón cuerda')],
        ),
      ]),
    ]);
    final json = Routine.fromJson(jsonDecode(jsonEncode(routine.toJson())));
    expect(json.days.single.items.single.alternatives.single.exerciseId, custom.id);

    final shared = decodeRoutine(encodeRoutine(routine, [custom]))!;
    expect(shared.routine.days.single.items.single.alternatives.single.slot, 'Jalón cuerda');
    expect(shared.customExercises.single.id, custom.id);
  });

  test('una rutina guardada antes de las alternativas se sigue leyendo', () {
    final old = RoutineItem.fromJson({'exerciseId': 'a', 'slot': 'A', 'sets': 3, 'reps': '10', 'restSeconds': 60});
    expect(old.alternatives, isEmpty);
    expect(old.toJson().containsKey('alternatives'), isFalse);
  });
}
