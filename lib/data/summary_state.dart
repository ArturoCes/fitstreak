import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import 'energy.dart';
import 'exercise_repository.dart';
import 'health_state.dart';
import 'progress_state.dart';
import 'summary.dart';

/// Today's summary, ready to be read aloud.
final dailySummaryProvider = FutureProvider.autoDispose<String?>((ref) async {
  final energy = await ref.watch(todayEnergyProvider.future);
  final routine = ref.watch(routineProvider);
  if (energy == null) return null;
  final next = ref.watch(nextDayIndexProvider);
  return dailySummary(
    now: DateTime.now(),
    goalKcal: energy.goalKcal,
    burnedKcal: energy.burnedKcal,
    eatenKcal: energy.eatenKcal,
    steps: energy.steps,
    logs: ref.watch(workoutLogsProvider),
    streak: ref.watch(streakProvider),
    nextDayName: routine == null || routine.days.isEmpty ? null : routine.days[next.clamp(0, routine.days.length - 1)].name,
  );
});

/// The current week compared with the previous one.
final weekReportProvider = Provider.autoDispose<WeekReport?>((ref) {
  final profile = ref.watch(profileProvider);
  if (profile == null) return null;
  return weekReport(
    logs: ref.watch(workoutLogsProvider),
    now: DateTime.now(),
    daysPerWeek: profile.daysPerWeek,
    streak: ref.watch(streakProvider),
    kcalOf: (l) => l.kcal ?? workoutKcal(weightKg: profile.weightKg, durationSeconds: l.durationSeconds),
  );
});

/// The spoken weekly analysis, with the exercise names.
final weekSummaryProvider = FutureProvider.autoDispose<String?>((ref) async {
  final report = ref.watch(weekReportProvider);
  if (report == null) return null;
  final exercises = await ref.watch(exercisesProvider.future);
  final names = {for (final e in exercises) e.id: e.name};
  // In an imported routine the Spanish name is the one the user wrote.
  final routine = ref.watch(routineProvider);
  for (final d in routine?.days ?? const []) {
    for (final i in d.items) {
      names[i.exerciseId] = i.slot;
    }
  }
  return weekSummary(report, nameOf: (id) => names[id] ?? id);
});
