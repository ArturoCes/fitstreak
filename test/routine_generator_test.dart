import 'dart:convert';
import 'dart:io';

import 'package:fitstreak/data/equipment_rules.dart';
import 'package:fitstreak/data/exercise.dart';
import 'package:fitstreak/data/routine_generator.dart';
import 'package:fitstreak/data/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile profile({
  Place place = Place.gym,
  Set<String>? equipment,
  Set<Injury> injuries = const {},
  int days = 3,
  int minutes = 45,
  Level level = Level.intermediate,
  Set<String> blocked = const {},
}) =>
    UserProfile(
      age: 28,
      heightCm: 175,
      weightKg: 75,
      goal: Goal.muscle,
      level: level,
      daysPerWeek: days,
      minutesPerSession: minutes,
      place: place,
      equipment: equipment ?? {...datasetEquipment, ...extraEquipment},
      injuries: injuries,
      blockedExercises: blocked,
    );

void main() {
  final all = [
    for (final e
        in jsonDecode(File('assets/data/exercises.json').readAsStringSync())
            as List<dynamic>)
      Exercise.fromJson(e as Map<String, dynamic>),
  ];
  final byId = {for (final e in all) e.id: e};

  List<Exercise> exercisesOf(RoutineGenerator g) => [
        for (final d in g.generate().days)
          for (final i in d.items) byId[i.exerciseId]!,
      ];

  test('gimnasio: días y ejercicios según días y minutos', () {
    for (final days in [2, 3, 4, 5, 6]) {
      final r = RoutineGenerator(profile(days: days, minutes: 60), all, seed: 1)
          .generate();
      expect(r.days.length, days);
      for (final d in r.days) {
        expect(d.items.length, 6, reason: d.name);
      }
    }
  });

  test('sin repetir ejercicios dentro de un mismo día', () {
    final r = RoutineGenerator(profile(days: 5, minutes: 75), all, seed: 2)
        .generate();
    for (final d in r.days) {
      final ids = d.items.map((i) => i.exerciseId).toList();
      expect(ids.toSet().length, ids.length, reason: d.name);
    }
  });

  test('casa solo con mancuernas: nada de máquinas, poleas ni dominadas', () {
    final p = profile(place: Place.home, equipment: {'dumbbell'});
    final ex = exercisesOf(RoutineGenerator(p, all, seed: 3));
    expect(ex, isNotEmpty);
    for (final e in ex) {
      expect({'dumbbell', 'body only'}, contains(e.equipmentOrBody), reason: e.name);
      expect(extraRequirements(e), isEmpty, reason: e.name);
    }
  });

  test('casa sin nada: rutina completa solo con peso corporal', () {
    final p = profile(place: Place.home, equipment: {}, minutes: 30);
    final r = RoutineGenerator(p, all, seed: 4).generate();
    for (final d in r.days) {
      expect(d.items.length, 4, reason: d.name);
      for (final i in d.items) {
        expect(byId[i.exerciseId]!.equipmentOrBody, 'body only');
      }
    }
  });

  test('lesión de rodilla y lumbar: sin saltos, zancadas ni pesos muertos', () {
    final p = profile(injuries: {Injury.knee, Injury.lowerBack}, days: 4);
    final names = exercisesOf(RoutineGenerator(p, all, seed: 5))
        .map((e) => e.name.toLowerCase());
    for (final n in names) {
      expect(n, isNot(matches(r'jump|lunge|deadlift|good morning')));
    }
  });

  test('principiante no recibe ejercicios de nivel avanzado', () {
    final p = profile(level: Level.beginner, days: 3, minutes: 75);
    for (final e in exercisesOf(RoutineGenerator(p, all, seed: 6))) {
      expect(e.level, isNot('expert'), reason: e.name);
    }
  });

  test('alternativas: mismo músculo, con el equipo disponible', () {
    final p = profile(place: Place.home, equipment: {'dumbbell', bench});
    final g = RoutineGenerator(p, all);
    final alts = g.alternatives(byId['Leg_Press']!);
    expect(alts, isNotEmpty);
    for (final a in alts) {
      expect(a.primaryMuscles, contains('quadriceps'));
      expect(hasEquipmentFor(a, p.equipment), isTrue, reason: a.name);
    }
  });

  test('los ejercicios bloqueados no vuelven a aparecer', () {
    final first = RoutineGenerator(profile(), all, seed: 7).generate();
    final blocked = first.days.first.items.first.exerciseId;
    final g = RoutineGenerator(profile(blocked: {blocked}), all, seed: 7);
    expect(exercisesOf(g).map((e) => e.id), isNot(contains(blocked)));
    expect(g.alternatives(byId[blocked]!).map((e) => e.id), isNot(contains(blocked)));
  });

  test('dominadas exigen barra y fondos en banco no', () {
    expect(extraRequirements(byId['Pullups']!), {pullUpBar});
    expect(extraRequirements(byId['Bench_Dips']!), isEmpty);
    expect(extraRequirements(byId['Dumbbell_Bench_Press']!), {bench});
  });
}
