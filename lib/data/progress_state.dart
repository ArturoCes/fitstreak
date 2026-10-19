import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notifications.dart';
import 'app_state.dart';
import 'streak.dart';

final notificationsProvider = Provider((_) => NotificationService());

const _streakKey = 'streak';
const _logsKey = 'workout_logs';
const _reminderKey = 'reminder_minutes';

class StreakNotifier extends Notifier<StreakState> {
  @override
  StreakState build() {
    final raw = ref.read(prefsProvider).getString(_streakKey);
    final saved = raw == null ? const StreakState() : StreakState.fromJson(jsonDecode(raw));
    // Al abrir la app se aplican los días pasados (protectores o racha rota).
    final evaluated = saved.evaluate(DateTime.now());
    if (raw != null) _persist(evaluated);
    return evaluated;
  }

  /// Guarda el entreno, suma a la racha y quita el aviso de esta noche.
  Future<void> completeWorkout(WorkoutLog log) async {
    final profile = ref.read(profileProvider)!;
    state = state.recordWorkout(log.date, daysPerWeek: profile.daysPerWeek);
    await _persist(state);
    await ref.read(workoutLogsProvider.notifier).add(log);
    await syncReminders();
  }

  Future<void> syncReminders() async {
    final now = DateTime.now();
    await ref
        .read(notificationsProvider)
        .scheduleAtRisk(streakDays: state.current(now), atRisk: state.atRisk(now));
  }

  Future<void> _persist(StreakState s) =>
      ref.read(prefsProvider).setString(_streakKey, jsonEncode(s.toJson()));
}

final streakProvider = NotifierProvider<StreakNotifier, StreakState>(StreakNotifier.new);

class WorkoutLogsNotifier extends Notifier<List<WorkoutLog>> {
  @override
  List<WorkoutLog> build() {
    final raw = ref.read(prefsProvider).getString(_logsKey);
    if (raw == null) return const [];
    return [
      for (final j in jsonDecode(raw) as List) WorkoutLog.fromJson(j as Map<String, dynamic>),
    ];
  }

  Future<void> add(WorkoutLog log) async {
    state = [...state, log];
    await ref
        .read(prefsProvider)
        .setString(_logsKey, jsonEncode([for (final l in state) l.toJson()]));
  }
}

final workoutLogsProvider = NotifierProvider<WorkoutLogsNotifier, List<WorkoutLog>>(
  WorkoutLogsNotifier.new,
);

/// Día de la rutina que toca: el siguiente al último entrenado.
final nextDayIndexProvider = Provider<int>((ref) {
  final days = ref.watch(routineProvider)?.days.length ?? 1;
  final logs = ref.watch(workoutLogsProvider);
  return logs.isEmpty ? 0 : (logs.last.dayIndex + 1) % days;
});

class ReminderNotifier extends Notifier<TimeOfDay?> {
  @override
  TimeOfDay? build() {
    final m = ref.read(prefsProvider).getInt(_reminderKey);
    return m == null ? null : TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  /// Activa (pidiendo permiso) o desactiva el recordatorio diario.
  /// Devuelve false si el sistema denegó el permiso.
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

final reminderProvider = NotifierProvider<ReminderNotifier, TimeOfDay?>(ReminderNotifier.new);
