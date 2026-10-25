import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notifications.dart';
import 'app_state.dart';
import 'streak.dart';

/// The app's local notification service (one instance).
final notificationsProvider = Provider((_) => NotificationService());

const _streakKey = 'streak';
const _logsKey = 'workout_logs';
const _reminderKey = 'reminder_minutes';

/// The user's streak, evaluated every time the app starts.
class StreakNotifier extends Notifier<StreakState> {
  /// Loads the saved streak, brings it up to the current rest rule and
  /// applies the days that passed (freezes spent or streak broken).
  @override
  StreakState build() {
    final raw = ref.read(prefsProvider).getString(_streakKey);
    var saved = raw == null ? const StreakState() : StreakState.fromJson(jsonDecode(raw));
    // Streaks saved under the previous rest rule (or before changing the days
    // per week) are updated before evaluating.
    final days = ref.read(profileProvider)?.daysPerWeek;
    if (days != null) saved = saved.withRestAllowance(days);
    // On app start, apply the past days (freezes or broken streak).
    final evaluated = saved.evaluate(DateTime.now());
    if (raw != null) _persist(evaluated);
    return evaluated;
  }

  /// Saves the workout, adds it to the streak and clears tonight's
  /// "streak at risk" reminder.
  Future<void> completeWorkout(WorkoutLog log) async {
    final profile = ref.read(profileProvider)!;
    state = state.recordWorkout(log.date, daysPerWeek: profile.daysPerWeek);
    await _persist(state);
    await ref.read(workoutLogsProvider.notifier).add(log);
    await syncReminders();
  }

  /// Reschedules tonight's "streak at risk" notification. A notification
  /// failure must not prevent opening the app or saving a workout, so errors
  /// are logged and ignored.
  Future<void> syncReminders() async {
    final now = DateTime.now();
    try {
      await ref
          .read(notificationsProvider)
          .scheduleAtRisk(streakDays: state.current(now), atRisk: state.atRisk(now));
    } catch (e) {
      debugPrint('No se pudo programar el aviso de racha: $e');
    }
  }

  /// Saves [s] to preferences.
  Future<void> _persist(StreakState s) =>
      ref.read(prefsProvider).setString(_streakKey, jsonEncode(s.toJson()));
}

/// The user's streak.
final streakProvider = NotifierProvider<StreakNotifier, StreakState>(StreakNotifier.new);

/// History of finished workouts, oldest first.
class WorkoutLogsNotifier extends Notifier<List<WorkoutLog>> {
  /// Loads the saved history.
  @override
  List<WorkoutLog> build() {
    final raw = ref.read(prefsProvider).getString(_logsKey);
    if (raw == null) return const [];
    return [
      for (final j in jsonDecode(raw) as List) WorkoutLog.fromJson(j as Map<String, dynamic>),
    ];
  }

  /// Appends [log] and saves the history.
  Future<void> add(WorkoutLog log) async {
    state = [...state, log];
    await ref
        .read(prefsProvider)
        .setString(_logsKey, jsonEncode([for (final l in state) l.toJson()]));
  }
}

/// Finished workouts, oldest first.
final workoutLogsProvider = NotifierProvider<WorkoutLogsNotifier, List<WorkoutLog>>(
  WorkoutLogsNotifier.new,
);

const _dayOverrideKey = 'day_override';

/// "Today is X" picked by hand, or day 1 when a new routine is set. It lasts
/// until the next workout (`afterLogs` = number of workouts when it was
/// picked); after that the days follow in order.
class DayOverrideNotifier extends Notifier<({int day, int afterLogs})?> {
  /// Loads the saved override, if any.
  @override
  ({int day, int afterLogs})? build() {
    final raw = ref.read(prefsProvider).getString(_dayOverrideKey);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return (day: j['day'] as int, afterLogs: j['afterLogs'] as int);
  }

  /// Makes [day] the next day to train until a workout is finished.
  Future<void> set(int day) async {
    final o = (day: day, afterLogs: ref.read(workoutLogsProvider).length);
    state = o;
    await ref.read(prefsProvider).setString(_dayOverrideKey, jsonEncode({'day': o.day, 'afterLogs': o.afterLogs}));
  }
}

/// The manual "today is X" override (null when the order is followed).
final dayOverrideProvider = NotifierProvider<DayOverrideNotifier, ({int day, int afterLogs})?>(
  DayOverrideNotifier.new,
);

/// Index of the routine day to train next: the manual override while it is
/// valid, otherwise the day after the last one trained.
final nextDayIndexProvider = Provider<int>((ref) {
  final days = ref.watch(routineProvider)?.days.length ?? 1;
  final logs = ref.watch(workoutLogsProvider);
  final o = ref.watch(dayOverrideProvider);
  if (o != null && logs.length == o.afterLogs) return o.day.clamp(0, days - 1);
  return logs.isEmpty ? 0 : (logs.last.dayIndex + 1) % days;
});

/// Time of the daily training reminder (null = off).
class ReminderNotifier extends Notifier<TimeOfDay?> {
  /// Loads the saved reminder time.
  @override
  TimeOfDay? build() {
    final m = ref.read(prefsProvider).getInt(_reminderKey);
    return m == null ? null : TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  /// Turns the daily reminder on at [time] (asking for permission) or off
  /// with null. Returns false if the system denied the permission.
  Future<bool> set(TimeOfDay? time) async {
    final notifications = ref.read(notificationsProvider);
    if (time != null && notifications.supported && !await notifications.requestPermission()) {
      return false;
    }
    state = time;
    final prefs = ref.read(prefsProvider);
    if (time == null) {
      await prefs.remove(_reminderKey);
    } else {
      await prefs.setInt(_reminderKey, time.hour * 60 + time.minute);
    }
    await notifications.scheduleDaily(time);
    return true;
  }
}

/// The daily reminder time.
final reminderProvider = NotifierProvider<ReminderNotifier, TimeOfDay?>(ReminderNotifier.new);
