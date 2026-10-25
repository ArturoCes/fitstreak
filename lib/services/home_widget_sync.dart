import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../data/app_state.dart';
import '../data/progress_state.dart';
import '../data/streak.dart';

/// What the streak home widget needs. Dates are stored rather than the
/// computed streak: StreakWidgetProvider.kt computes it with the current
/// date, so it doesn't go stale when the app isn't opened.
@visibleForTesting
Map<String, Object?> homeWidgetData({
  required StreakState streak,
  required List<WorkoutLog> logs,
  required String? nextDay,
  required DateTime now,
}) {
  String? day(DateTime? d) => d == null ? null : StreakState.key(d);
  final from = addDays(now, -7);
  final sets = <String, int>{};
  for (final l in logs) {
    if (l.date.isBefore(from)) continue;
    final k = StreakState.key(l.date);
    sets[k] = (sets[k] ?? 0) + l.setsDone;
  }
  return {
    'streak_start': day(streak.streakStart) ?? '',
    'protected_until': day(streak.protectedUntil) ?? '',
    'last_workout': day(streak.lastWorkout) ?? '',
    'freezes': streak.freezes,
    'day_sets': [for (final e in sets.entries) '${e.key}=${e.value}'].join(';'),
    'next_day': nextDay ?? '',
  };
}

/// Keeps the widget up to date when the streak, the history or the next
/// day change. Activated with a ref.watch from the app.
final homeWidgetSyncProvider = Provider<void>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final streak = ref.watch(streakProvider);
  final logs = ref.watch(workoutLogsProvider);
  final days = ref.watch(routineProvider)?.days;
  final next = days == null || days.isEmpty ? null : days[ref.watch(nextDayIndexProvider).clamp(0, days.length - 1)].name;
  final data = homeWidgetData(streak: streak, logs: logs, nextDay: next, now: DateTime.now());
  Future(() async {
    try {
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData(e.key, e.value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: 'com.arturoc.fitstreak.StreakWidgetProvider');
    } catch (e) {
      debugPrint('No se pudo actualizar el widget: $e');
    }
  });
});
