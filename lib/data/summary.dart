// Text summaries, written to be read aloud and shown in notifications:
// "Llevas 1.650 de 2.100 kilocalorías: te faltan 450. Hoy entrenaste Pull..."

import 'progression.dart';
import 'streak.dart';

/// Spanish thousands separator ("1.650"), so text-to-speech reads it as a
/// number ("mil seiscientos cincuenta").
String thousands(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// Spoken Spanish duration: "1 hora y 5 minutos", "52 minutos".
String spokenDuration(int seconds) {
  final m = (seconds / 60).round();
  if (m < 60) return '$m ${m == 1 ? 'minuto' : 'minutos'}';
  final h = m ~/ 60, rest = m % 60;
  final hs = '$h ${h == 1 ? 'hora' : 'horas'}';
  return rest == 0 ? hs : '$hs y $rest minutos';
}

/// "1 día" / "5 días".
String _days(int n) => '$n ${n == 1 ? 'día' : 'días'}';

/// Today's summary: calories, workout, steps and streak.
String dailySummary({
  required DateTime now,
  required int goalKcal,
  required int burnedKcal,
  required int? eatenKcal,
  required int? steps,
  required List<WorkoutLog> logs,
  required StreakState streak,
  required String? nextDayName,
}) {
  final parts = <String>[];
  if (eatenKcal != null) {
    final left = goalKcal - eatenKcal;
    parts.add(left >= 0
        ? 'Llevas ${thousands(eatenKcal)} de ${thousands(goalKcal)} kilocalorías: te faltan ${thousands(left)}.'
        : 'Llevas ${thousands(eatenKcal)} kilocalorías: te has pasado ${thousands(-left)} de tu meta.');
  } else {
    parts.add('Tu meta de hoy es de ${thousands(goalKcal)} kilocalorías.');
  }

  final today = [for (final l in logs) if (dateOnly(l.date) == dateOnly(now)) l];
  if (today.isNotEmpty) {
    final sets = today.fold(0, (a, l) => a + l.setsDone);
    final secs = today.fold(0, (a, l) => a + l.durationSeconds);
    final names = {for (final l in today) l.dayName}.join(' y ');
    parts.add('Hoy entrenaste $names: $sets series en ${spokenDuration(secs)}.');
  } else if (nextDayName != null) {
    parts.add('Hoy aún no has entrenado. Te toca $nextDayName.');
  }
  if (burnedKcal > 0) parts.add('Has gastado unas ${thousands(burnedKcal)} kilocalorías activas.');
  if (steps != null && steps > 0) parts.add('Llevas ${thousands(steps)} pasos.');

  final days = streak.current(now);
  if (days > 0) {
    parts.add('Tu racha es de ${_days(days)}.');
    if (streak.atRisk(now)) parts.add('Entrena hoy para no perderla.');
  }
  return parts.join(' ');
}

/// Text of the evening notification. It is scheduled in the morning or after
/// training, so it carries no calories (they change during the day): only
/// what is certain; tapping it opens the summary with live figures.
String dailyNotificationText({
  required DateTime now,
  required List<WorkoutLog> logs,
  required StreakState streak,
  required String? nextDayName,
}) {
  final today = [for (final l in logs) if (dateOnly(l.date) == dateOnly(now)) l];
  final parts = <String>[
    if (today.isNotEmpty)
      'Hoy entrenaste ${{for (final l in today) l.dayName}.join(' y ')} '
          '(${today.fold(0, (a, l) => a + l.setsDone)} series).'
    else if (nextDayName != null)
      'Hoy no has entrenado: te tocaba $nextDayName.',
    if (streak.current(now) > 0) 'Racha: ${_days(streak.current(now))}.',
    'Toca para ver cuántas calorías te faltan.',
  ];
  return parts.join(' ');
}

/// A record of the week: more weight than ever on an exercise.
class PersonalRecord {
  /// Creates a record.
  const PersonalRecord({required this.exerciseId, required this.kg, required this.reps});

  /// Exercise of the record.
  final String exerciseId;

  /// New best weight.
  final double kg;

  /// Reps done with it.
  final int reps;
}

/// The current week (Monday to today) compared with the previous one.
class WeekReport {
  /// Creates a report.
  const WeekReport({
    required this.workouts,
    required this.planned,
    required this.sets,
    required this.seconds,
    required this.volumeKg,
    required this.kcal,
    required this.records,
    required this.previousWorkouts,
    required this.previousVolumeKg,
    required this.streakDays,
  });

  /// Days trained this week.
  final int workouts;

  /// Days planned per week.
  final int planned;

  /// Sets done this week.
  final int sets;

  /// Active training time this week.
  final int seconds;

  /// Total reps × kg this week.
  final double volumeKg;

  /// Active calories of this week's workouts.
  final int kcal;

  /// New weight records this week.
  final List<PersonalRecord> records;

  /// Days trained last week.
  final int previousWorkouts;

  /// Total reps × kg last week.
  final double previousVolumeKg;

  /// Current streak length.
  final int streakDays;
}

/// Sum of reps × kg of [logs].
double _volume(Iterable<WorkoutLog> logs) => logs.fold(
      0.0,
      (a, l) => a + l.exercises.fold(0.0, (b, e) => b + e.sets.fold(0.0, (c, s) => c + s.reps * (s.weightKg ?? 0))),
    );

/// Builds the report of the week containing [now]. [kcalOf] estimates the
/// calories of workouts saved without them.
WeekReport weekReport({
  required List<WorkoutLog> logs,
  required DateTime now,
  required int daysPerWeek,
  required StreakState streak,
  required int Function(WorkoutLog) kcalOf,
}) {
  final monday = addDays(now, 1 - now.weekday);
  final prevMonday = addDays(monday, -7);
  final week = [for (final l in logs) if (!l.date.isBefore(monday)) l];
  final prev = [for (final l in logs) if (!l.date.isBefore(prevMonday) && l.date.isBefore(monday)) l];

  // Record: the week's best weight beats the best before (and there was one).
  final bestBefore = <String, double>{};
  for (final l in logs.where((l) => l.date.isBefore(monday))) {
    for (final e in l.exercises) {
      for (final s in e.sets) {
        final kg = s.weightKg ?? 0;
        if (kg > (bestBefore[e.exerciseId] ?? 0)) bestBefore[e.exerciseId] = kg;
      }
    }
  }
  final bestNow = <String, SetLog>{};
  for (final l in week) {
    for (final e in l.exercises) {
      for (final s in e.sets) {
        final cur = bestNow[e.exerciseId];
        final kg = s.weightKg ?? 0;
        if (cur == null || kg > (cur.weightKg ?? 0) || (kg == (cur.weightKg ?? 0) && s.reps > cur.reps)) {
          bestNow[e.exerciseId] = s;
        }
      }
    }
  }
  final records = [
    for (final MapEntry(key: id, value: s) in bestNow.entries)
      if ((s.weightKg ?? 0) > 0 && bestBefore.containsKey(id) && s.weightKg! > bestBefore[id]!)
        PersonalRecord(exerciseId: id, kg: s.weightKg!, reps: s.reps),
  ];

  return WeekReport(
    workouts: {for (final l in week) StreakState.key(l.date)}.length,
    planned: daysPerWeek,
    sets: week.fold(0, (a, l) => a + l.setsDone),
    seconds: week.fold(0, (a, l) => a + l.durationSeconds),
    volumeKg: _volume(week),
    kcal: week.fold(0, (a, l) => a + kcalOf(l)),
    records: records,
    previousWorkouts: {for (final l in prev) StreakState.key(l.date)}.length,
    previousVolumeKg: _volume(prev),
    streakDays: streak.current(now),
  );
}

/// Spoken weekly analysis: workouts, volume, records and streak. [nameOf]
/// gives the name to say for an exercise id.
String weekSummary(WeekReport r, {required String Function(String exerciseId) nameOf}) {
  final parts = <String>[];
  if (r.workouts == 0) {
    parts.add('Esta semana aún no has entrenado. Tu plan es de ${_days(r.planned)}.');
  } else {
    parts.add('Esta semana llevas ${r.workouts} de ${r.planned} entrenos: '
        '${r.sets} series en ${spokenDuration(r.seconds)}.');
    if (r.volumeKg > 0) parts.add('Has movido ${thousands(r.volumeKg.round())} kilos en total.');
    if (r.kcal > 0) parts.add('Unas ${thousands(r.kcal)} kilocalorías gastadas entrenando.');
    if (r.records.isNotEmpty) {
      final list = r.records
          .take(3)
          .map((p) => '${nameOf(p.exerciseId)} con ${formatKg(p.kg).replaceAll('.', ',')} kilos')
          .join(', ');
      parts.add(r.records.length == 1 ? 'Nuevo récord: $list.' : 'Nuevos récords: $list.');
    }
  }
  final diff = r.workouts - r.previousWorkouts;
  if (r.previousWorkouts > 0 && diff != 0) {
    parts.add(diff > 0
        ? '${diff == 1 ? 'Un entreno' : '$diff entrenos'} más que la semana pasada.'
        : '${-diff == 1 ? 'Un entreno' : '${-diff} entrenos'} menos que la semana pasada.');
  }
  if (r.workouts >= r.planned && r.planned > 0) parts.add('¡Has cumplido tu plan!');
  if (r.streakDays > 0) parts.add('Tu racha es de ${_days(r.streakDays)}.');
  return parts.join(' ');
}
