import 'dart:convert';
import 'dart:io';

import 'package:fitstreak/data/exercise.dart';
import 'package:fitstreak/data/routine_import.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = [
    for (final e in jsonDecode(File('assets/data/exercises.json').readAsStringSync()) as List)
      Exercise.fromJson(e as Map<String, dynamic>),
  ];
  final text = File('test/fixtures/rutina_whatsapp.txt').readAsStringSync();
  final parsed = parseRoutineText(text);

  test('saca los 4 días con sus nombres y recordatorios', () {
    expect([for (final d in parsed.days) d.name], ['Push', 'Pull', 'Piernas + Core', 'Upper']);
    expect([for (final d in parsed.days) d.items.length], [6, 6, 5, 6]);
    expect(parsed.days[0].note, contains('Pecho/hombro + toque bíceps'));
    expect(parsed.days[0].note, contains('NO reventar bíceps aquí'));
    expect(parsed.days[1].note, contains('día clave de brazos'));
  });

  test('series, repeticiones y comentarios', () {
    final push = parsed.days[0].items;
    expect(push[0].name, 'Press banca');
    expect((push[0].sets, push[0].reps), (4, '6-10'));
    expect((push[3].sets, push[3].reps), (3, '8-12')); // "3x8 -12"
    expect(push[5].name, 'Curl barra recta');
    expect(push[5].note, 'Ligero');
    final legs = parsed.days[2].items;
    expect(legs[0].note, 'Rack');
    expect((legs[4].name, legs[4].sets), ('Rueda abdominal', 3));
  });

  test('descansos y notas generales', () {
    expect(parsed.bigRest, 150); // 2–3 min
    expect(parsed.smallRest, 75); // 60–90 seg
    expect(parsed.notes, hasLength(3));
    expect(parsed.notes[0], startsWith('Descansos'));
    expect(parsed.notes[2], contains('❌ No hacer 20 ejercicios'));
  });

  test('cada ejercicio encuentra su equivalente del catálogo', () {
    final expected = {
      'Press banca': 'Barbell_Bench_Press_-_Medium_Grip',
      'Press inclinado mancuernas': 'Incline_Dumbbell_Press',
      'Press hombro mancuernas': 'Dumbbell_Shoulder_Press',
      'Elevaciones laterales': 'Side_Lateral_Raise',
      'Fondos': 'Dips_-_Chest_Version',
      'Curl barra recta': 'Barbell_Curl',
      'Dominadas': 'Pullups',
      'Jalón espalda': 'Wide-Grip_Lat_Pulldown',
      'Remo mancuerna': 'One-Arm_Dumbbell_Row',
      'Curl bayesian': 'Incline_Dumbbell_Curl',
      'Curl martillo': 'Hammer_Curls',
      'Sentadilla': 'Barbell_Squat',
      'Peso muerto rumano': 'Romanian_Deadlift',
      'Extensión cuádriceps': 'Leg_Extensions',
      'Gemelos': 'Standing_Calf_Raises',
      'Rueda abdominal': 'Ab_Roller',
      'Press inclinado': 'Barbell_Incline_Bench_Press_-_Medium_Grip',
      'Remo': 'Bent_Over_Barbell_Row',
      'Curl concentrado': 'Concentration_Curls',
      'Fondos cerrados': 'Dips_-_Triceps_Version',
    };
    for (final day in parsed.days) {
      for (final item in day.items) {
        final m = matchExercise(item.name, catalog);
        expect(m.exercise?.id, expected[item.name], reason: item.name);
      }
    }
    expect(matchExercise('Curl bayesian', catalog).quality, MatchQuality.approximate);
    expect(matchExercise('Press banca', catalog).quality, MatchQuality.exact);
  });

  test('todos los alias apuntan a ejercicios que existen', () {
    final ids = {for (final e in catalog) e.id};
    expect([for (final id in aliasExerciseIds) if (!ids.contains(id)) id], isEmpty);
  });

  test('los ejercicios de bíceps descansan menos', () {
    final byName = {for (final e in catalog) e.id: e};
    expect(looksIsolation('Curl martillo', byName['Hammer_Curls']), isTrue);
    expect(looksIsolation('Sentadilla', byName['Barbell_Squat']), isFalse);
  });

  test('lo que no existe se queda sin pareja', () {
    expect(matchExercise('Burpees con palmada en el aire', catalog).quality, isNot(MatchQuality.exact));
    expect(customEquipmentFor('Remo con barra landmine'), 'barbell');
  });

  test('formatos sueltos: sin días, minutos y "series de"', () {
    final p = parseRoutineText('Plancha 3x1 min\nSentadilla 4 series de 10\nZancadas: 3 x 12');
    expect(p.days, hasLength(1));
    final items = p.days.single.items;
    expect((items[0].sets, items[0].reps), (3, '60 s'));
    expect((items[1].sets, items[1].reps), (4, '10'));
    expect((items[2].name, items[2].reps), ('Zancadas', '12'));
  });
}
