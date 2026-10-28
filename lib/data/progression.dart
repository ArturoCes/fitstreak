import 'dart:math';

import 'exercise.dart';
import 'routine.dart';
import 'streak.dart';

/// Equipment for which logging kilograms makes sense.
const _weightedEquipment = {
  'barbell',
  'dumbbell',
  'kettlebells',
  'cable',
  'machine',
  'e-z curl bar',
  'medicine ball',
};

/// Whether [e] is loaded, so the workout asks for kilograms.
bool usesWeight(Exercise e) => _weightedEquipment.contains(e.equipmentOrBody);

/// Most reps a set can log.
const maxSetReps = 100;

/// Longest timed hold a set can log, in seconds.
const maxHoldSeconds = 600;

/// Heaviest weight a set can log, in kg.
const maxSetKg = 500.0;

/// Timed holds (plank...): seconds are logged instead of reps.
bool isTimed(RoutineItem item) => item.reps.contains('s');

/// Parses a rep range: "8-10" → (8, 10); "15" → (15, 15); "30-45 s" → (30, 45).
(int, int) repRange(String reps) {
  final nums = RegExp(r'\d+').allMatches(reps).map((m) => int.parse(m[0]!)).toList();
  if (nums.isEmpty) return (10, 10);
  return (nums.first, nums.length > 1 ? nums[1] : nums.first);
}

/// How much to add once a weight is mastered: little on dumbbells and
/// kettlebells (it is per hand), more on barbells and machines.
double weightStep(Exercise e) => switch (e.equipmentOrBody) {
      'dumbbell' || 'kettlebells' || 'medicine ball' => 1,
      _ => 2.5,
    };

/// What is suggested for today's session.
class SetPlan {
  /// Creates a plan.
  const SetPlan({required this.sets, required this.last, required this.levelUp, this.levelUpSets});

  /// What is prefilled when the workout starts: exactly last time's sets.
  final List<SetLog> sets;

  /// Last time this exercise was done (null if it is the first time).
  final ExerciseLog? last;

  /// True when it is time to add weight (or reps when unloaded).
  final bool levelUp;

  /// The progression proposal (more weight with the minimum reps, or one
  /// more rep when unloaded). Only applied if the user wants to.
  final List<SetLog>? levelUpSets;
}

/// Last logged session of an exercise ([logs] go from oldest to newest).
///
/// With [dayName], the last time it was done on that routine day comes
/// first: a curl can be light on push day and heavy on pull day, and each
/// day should suggest its own numbers. If it was never done that day, the
/// last time on any day.
ExerciseLog? lastSession(List<WorkoutLog> logs, String exerciseId, {String? dayName}) {
  ExerciseLog? any;
  for (final log in logs.reversed) {
    for (final e in log.exercises) {
      if (e.exerciseId != exerciseId || e.sets.isEmpty) continue;
      if (dayName == null || log.dayName == dayName) return e;
      any ??= e;
    }
  }
  return any;
}

/// Today's proposal: the same as last time, set by set (weight and reps). If
/// every set reached the top of the range, raising the weight (or one more
/// rep when unloaded) is also offered, without applying it (double
/// progression).
SetPlan planSets(RoutineItem item, Exercise exercise, ExerciseLog? last) {
  final (minReps, maxReps) = repRange(item.reps);
  final weighted = usesWeight(exercise);

  if (last == null) {
    return SetPlan(
      sets: [for (var i = 0; i < item.sets; i++) SetLog(reps: minReps, weightKg: weighted ? 0 : null)],
      last: null,
      levelUp: false,
    );
  }

  SetLog prevAt(int i) => last.sets[min(i, last.sets.length - 1)];
  final sets = [
    for (var i = 0; i < item.sets; i++)
      SetLog(reps: prevAt(i).reps, weightKg: weighted ? (prevAt(i).weightKg ?? 0) : null),
  ];

  final mastered = last.sets.every((s) => s.reps >= maxReps);
  final hasLoad = (last.sets.first.weightKg ?? 0) > 0;
  final levelUp = mastered && (!weighted || hasLoad);
  return SetPlan(
    sets: sets,
    last: last,
    levelUp: levelUp,
    levelUpSets: !levelUp
        ? null
        : [
            for (final s in sets)
              weighted
                  ? SetLog(reps: minReps, weightKg: (s.weightKg ?? 0) + weightStep(exercise))
                  : SetLog(reps: s.reps + 1),
          ],
  );
}

/// Short text of a session: "10×4 kg · 10×4 kg · 8×4 kg".
String describeSets(List<SetLog> sets, {bool timed = false}) => sets
    .map((s) => s.weightKg != null && s.weightKg! > 0
        ? '${s.reps}×${formatKg(s.weightKg!)} kg'
        : timed
            ? '${s.reps} s'
            : '${s.reps} reps')
    .join(' · ');

/// Kilograms without trailing zeros: 40 → "40", 42.5 → "42.5".
String formatKg(double kg) => kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);

/// One point of an exercise's progress chart (one session).
class ProgressPoint {
  /// Creates a point.
  const ProgressPoint({
    required this.date,
    required this.bestWeight,
    required this.bestReps,
    required this.volume,
    required this.sets,
  });

  /// Session date.
  final DateTime date;

  /// Heaviest weight of the session (0 when unloaded).
  final double bestWeight;

  /// Reps of the best set.
  final int bestReps;

  /// Sum of reps × kg (or reps when unloaded).
  final double volume;

  /// All the sets of the session.
  final List<SetLog> sets;

  /// Estimated one-rep max (Epley formula), to compare sessions with
  /// different reps.
  double get estimated1RM => bestWeight * (1 + bestReps / 30);
}

/// Progress points of [exerciseId], one per session, oldest first.
List<ProgressPoint> progressFor(List<WorkoutLog> logs, String exerciseId) => [
      for (final log in logs)
        for (final e in log.exercises)
          if (e.exerciseId == exerciseId && e.sets.isNotEmpty) _point(log.date, e.sets),
    ];

/// Summarizes one session's [sets] into a chart point.
ProgressPoint _point(DateTime date, List<SetLog> sets) {
  var best = sets.first;
  for (final s in sets) {
    final w = s.weightKg ?? 0;
    final bw = best.weightKg ?? 0;
    if (w > bw || (w == bw && s.reps > best.reps)) best = s;
  }
  final volume = sets.fold<double>(
    0,
    (a, s) => a + s.reps * ((s.weightKg ?? 0) > 0 ? s.weightKg! : 1),
  );
  return ProgressPoint(
    date: date,
    bestWeight: best.weightKg ?? 0,
    bestReps: best.reps,
    volume: volume,
    sets: sets,
  );
}

/// Workouts per week (Monday to Sunday) over the last [weeks] weeks; the
/// last entry is the current week.
List<int> workoutsPerWeek(List<WorkoutLog> logs, DateTime today, {int weeks = 8}) {
  final t = dateOnly(today);
  final thisMonday = addDays(t, 1 - t.weekday);
  final counts = List.filled(weeks, 0);
  for (final log in logs) {
    final d = dateOnly(log.date);
    final weeksAgo = daysBetween(addDays(d, 1 - d.weekday), thisMonday) ~/ 7;
    if (weeksAgo >= 0 && weeksAgo < weeks) counts[weeks - 1 - weeksAgo]++;
  }
  return counts;
}
