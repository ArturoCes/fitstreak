import 'package:fitstreak/data/exercise.dart';
import 'package:fitstreak/data/progression.dart';
import 'package:fitstreak/data/routine.dart';
import 'package:fitstreak/data/streak.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise ex(String id, String? equipment) => Exercise(
      id: id,
      name: id,
      level: 'beginner',
      category: 'strength',
      primaryMuscles: const ['biceps'],
      secondaryMuscles: const [],
      instructions: const [],
      images: const [],
      equipment: equipment,
    );

RoutineItem item(String id, {int sets = 3, String reps = '8-10'}) =>
    RoutineItem(exerciseId: id, slot: 'x', sets: sets, reps: reps, restSeconds: 60);

WorkoutLog log(DateTime date, String id, List<SetLog> sets, {String day = 'A'}) => WorkoutLog(
      date: date,
      dayIndex: 0,
      dayName: day,
      setsDone: sets.length,
      setsTotal: sets.length,
      durationSeconds: 600,
      exercises: [ExerciseLog(exerciseId: id, sets: sets)],
    );

void main() {
  final curl = ex('curl', 'dumbbell');
  final pushups = ex('pushups', 'body only');

  test('rango de repeticiones', () {
    expect(repRange('8-10'), (8, 10));
    expect(repRange('15'), (15, 15));
    expect(repRange('30-45 s'), (30, 45));
  });

  test('primera vez: el mínimo del rango y peso por rellenar', () {
    final p = planSets(item('curl'), curl, null);
    expect(p.sets.length, 3);
    expect(p.sets.every((s) => s.reps == 8 && s.weightKg == 0), isTrue);
    expect(p.levelUp, isFalse);
  });

  test('el ejemplo: lunes 10 reps con 4 kg → la próxima, al menos 10 × 4 kg', () {
    // Rango 10-12: 10 reps no es el tope, así que repite lo mismo.
    final monday = [for (var i = 0; i < 3; i++) const SetLog(reps: 10, weightKg: 4)];
    final last = lastSession([log(DateTime(2026, 10, 19), 'curl', monday)], 'curl');
    final p = planSets(item('curl', reps: '10-12'), curl, last);
    for (final s in p.sets) {
      expect(s.reps, greaterThanOrEqualTo(10));
      expect(s.weightKg, greaterThanOrEqualTo(4));
    }
    expect(p.levelUp, isFalse);
  });

  test('si llegas al tope del rango, propone subir peso pero rellena lo que hiciste', () {
    final sets = [for (var i = 0; i < 3; i++) const SetLog(reps: 10, weightKg: 4)];
    final last = ExerciseLog(exerciseId: 'curl', sets: sets);
    final p = planSets(item('curl'), curl, last); // rango 8-10
    expect(p.levelUp, isTrue);
    // Lo que se rellena: tus 10 reps con 4 kg.
    expect((p.sets.first.reps, p.sets.first.weightKg), (10, 4));
    // La propuesta para progresar: +1 kg en mancuernas, vuelta al mínimo.
    expect((p.levelUpSets!.first.reps, p.levelUpSets!.first.weightKg), (8, 5));
  });

  test('sin llegar al tope repite tus números exactos por serie', () {
    const last = ExerciseLog(exerciseId: 'curl', sets: [
      SetLog(reps: 10, weightKg: 6),
      SetLog(reps: 9, weightKg: 6),
      SetLog(reps: 7, weightKg: 6),
    ]);
    final p = planSets(item('curl'), curl, last);
    expect(p.sets.map((s) => s.reps), [10, 9, 7]); // lo que hiciste, serie a serie
    expect(p.levelUpSets, isNull);
    expect(p.sets.every((s) => s.weightKg == 6), isTrue);
  });

  test('peso corporal: sin kg y +1 repetición al dominarlo', () {
    final last = ExerciseLog(
      exerciseId: 'pushups',
      sets: [for (var i = 0; i < 3; i++) const SetLog(reps: 10)],
    );
    final p = planSets(item('pushups'), pushups, last);
    expect(p.sets.every((s) => s.weightKg == null && s.reps == 10), isTrue);
    expect(p.levelUp, isTrue);
    expect(p.levelUpSets!.every((s) => s.reps == 11), isTrue);
  });

  test('la sesión anterior es la más reciente', () {
    final logs = [
      log(DateTime(2026, 10, 1), 'curl', const [SetLog(reps: 8, weightKg: 2)]),
      log(DateTime(2026, 10, 8), 'curl', const [SetLog(reps: 8, weightKg: 3)]),
    ];
    expect(lastSession(logs, 'curl')!.sets.first.weightKg, 3);
    expect(lastSession(logs, 'otro'), isNull);
  });

  test('cada día sugiere lo que se hizo ese día', () {
    final logs = [
      log(DateTime(2026, 10, 20), 'curl', const [SetLog(reps: 12, weightKg: 20)], day: 'Empuje'),
      log(DateTime(2026, 10, 21), 'curl', const [SetLog(reps: 12, weightKg: 1)], day: 'Tirón'),
    ];
    expect(lastSession(logs, 'curl', dayName: 'Empuje')!.sets.first.weightKg, 20);
    expect(lastSession(logs, 'curl', dayName: 'Tirón')!.sets.first.weightKg, 1);
    // Never done on leg day: the last time on any day.
    expect(lastSession(logs, 'curl', dayName: 'Pierna')!.sets.first.weightKg, 1);
  });

  test('puntos de progreso y 1RM estimado', () {
    final logs = [
      log(DateTime(2026, 10, 1), 'curl', const [SetLog(reps: 10, weightKg: 4), SetLog(reps: 8, weightKg: 5)]),
      log(DateTime(2026, 10, 8), 'curl', const [SetLog(reps: 10, weightKg: 6)]),
    ];
    final pts = progressFor(logs, 'curl');
    expect(pts.length, 2);
    expect(pts.first.bestWeight, 5);
    expect(pts.first.bestReps, 8);
    expect(pts.first.volume, 10 * 4 + 8 * 5);
    expect(pts.last.estimated1RM, closeTo(6 * (1 + 10 / 30), 0.001));
  });

  test('entrenos por semana', () {
    final today = DateTime(2026, 10, 21); // miércoles
    final logs = [
      log(DateTime(2026, 10, 19), 'a', const []),
      log(DateTime(2026, 10, 20), 'a', const []),
      log(DateTime(2026, 10, 14), 'a', const []),
      log(DateTime(2026, 8, 1), 'a', const []), // fuera del rango
    ];
    final weeks = workoutsPerWeek(logs, today);
    expect(weeks.length, 8);
    expect(weeks.last, 2);
    expect(weeks[6], 1);
    expect(weeks.reduce((a, b) => a + b), 3);
  });

  test('los entrenos guardados sin series siguen cargando', () {
    final old = WorkoutLog.fromJson({
      'date': '2026-10-01T10:00:00.000',
      'dayIndex': 0,
      'dayName': 'A',
      'setsDone': 4,
      'setsTotal': 8,
      'durationSeconds': 900,
    });
    expect(old.exercises, isEmpty);
    final roundTrip = WorkoutLog.fromJson(log(DateTime(2026, 10, 2), 'curl', const [SetLog(reps: 5, weightKg: 2.5)]).toJson());
    expect(roundTrip.exercises.single.sets.single.weightKg, 2.5);
  });
}
