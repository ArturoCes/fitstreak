import 'package:fitstreak/data/streak.dart';
import 'package:fitstreak/data/summary.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutLog _log(DateTime date, String day, {int sets = 20, int secs = 3120, double kg = 40, int reps = 10}) => WorkoutLog(
      date: date,
      dayIndex: 0,
      dayName: day,
      setsDone: sets,
      setsTotal: sets,
      durationSeconds: secs,
      kcal: 260,
      exercises: [
        ExerciseLog(exerciseId: 'bench', sets: [SetLog(reps: reps, weightKg: kg), SetLog(reps: reps, weightKg: kg)]),
      ],
    );

void main() {
  // Domingo 25 de octubre de 2026, por la tarde.
  final now = DateTime(2026, 10, 25, 18);

  test('números como se dicen', () {
    expect(thousands(1650), '1.650');
    expect(thousands(950), '950');
    expect(thousands(12345), '12.345');
    expect(spokenDuration(3120), '52 minutos');
    expect(spokenDuration(3900), '1 hora y 5 minutos');
  });

  test('resumen de hoy con calorías, entreno, pasos y racha', () {
    final streak = const StreakState().recordWorkout(now, daysPerWeek: 4);
    final text = dailySummary(
      now: now,
      goalKcal: 2100,
      burnedKcal: 420,
      eatenKcal: 1650,
      steps: 8432,
      logs: [_log(now, 'Pull')],
      streak: streak,
      nextDayName: 'Piernas',
    );
    expect(text, contains('Llevas 1.650 de 2.100 kilocalorías: te faltan 450.'));
    expect(text, contains('Hoy entrenaste Pull: 20 series en 52 minutos.'));
    expect(text, contains('8.432 pasos'));
    expect(text, contains('Tu racha es de 1 día.'));
  });

  test('sin Fitia dice la meta; sin entrenar dice lo que toca', () {
    final text = dailySummary(
      now: now,
      goalKcal: 2100,
      burnedKcal: 0,
      eatenKcal: null,
      steps: null,
      logs: const [],
      streak: const StreakState(),
      nextDayName: 'Push',
    );
    expect(text, 'Tu meta de hoy es de 2.100 kilocalorías. Hoy aún no has entrenado. Te toca Push.');
  });

  test('análisis de la semana: entrenos, kilos, récords y comparación', () {
    final logs = [
      _log(DateTime(2026, 10, 14), 'Push', kg: 40), // semana pasada
      _log(DateTime(2026, 10, 20), 'Push', kg: 42.5), // esta semana: récord
      _log(DateTime(2026, 10, 21), 'Pull'),
      _log(DateTime(2026, 10, 22), 'Piernas'),
    ];
    final r = weekReport(
      logs: logs,
      now: now,
      daysPerWeek: 4,
      streak: const StreakState(),
      kcalOf: (l) => l.kcal!,
    );
    expect((r.workouts, r.planned, r.previousWorkouts), (3, 4, 1));
    expect(r.sets, 60);
    expect(r.kcal, 780);
    expect(r.records.single.kg, 42.5);
    final text = weekSummary(r, nameOf: (id) => 'Press banca');
    expect(text, startsWith('Esta semana llevas 3 de 4 entrenos: 60 series en 2 horas y 36 minutos.'));
    expect(text, contains('Nuevo récord: Press banca con 42,5 kilos.'));
    expect(text, contains('2 entrenos más que la semana pasada.'));
  });

  test('la notificación de la noche no promete calorías que cambian', () {
    final text = dailyNotificationText(now: now, logs: const [], streak: const StreakState(), nextDayName: 'Upper');
    expect(text, 'Hoy no has entrenado: te tocaba Upper. Toca para ver cuántas calorías te faltan.');
  });
}
