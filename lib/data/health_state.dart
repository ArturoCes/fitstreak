// Health Connect (Android): the "health hub" where the watch (Samsung
// Health, Google Fit...) stores steps and calories, and Fitia or other food
// apps store what you eat. FitStreak reads from it and writes its workouts.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import 'app_state.dart';
import 'energy.dart';
import 'progress_state.dart';
import 'streak.dart';

/// Whether Health Connect can be used here (Android only).
bool get healthSupported => !kIsWeb && Platform.isAndroid;

const _readTypes = [
  HealthDataType.STEPS,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.TOTAL_CALORIES_BURNED,
  HealthDataType.NUTRITION,
];
const _writeTypes = [HealthDataType.WORKOUT, HealthDataType.TOTAL_CALORIES_BURNED];

const _connectedKey = 'health_connected';

/// Outcome of asking to connect Health Connect.
enum HealthConnectResult {
  /// Permissions granted.
  connected,

  /// The user refused the permissions.
  denied,

  /// Health Connect must be installed first (the Play Store was opened).
  notInstalled,

  /// Not available on this platform.
  unsupported,
}

/// Whether the user linked Health Connect, plus reading today's data and
/// writing finished workouts.
class HealthNotifier extends Notifier<bool> {
  final _health = Health();
  bool _configured = false;

  /// True when the user connected Health Connect.
  @override
  bool build() => healthSupported && (ref.read(prefsProvider).getBool(_connectedKey) ?? false);

  /// Initializes the plugin once.
  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Asks for the read and write permissions (installing Health Connect
  /// first on Android 13 or older).
  Future<HealthConnectResult> connect() async {
    if (!healthSupported) return HealthConnectResult.unsupported;
    await _configure();
    final status = await _health.getHealthConnectSdkStatus();
    if (status != HealthConnectSdkStatus.sdkAvailable) {
      // Android 13 or older: Health Connect must be installed from Play.
      await _health.installHealthConnect();
      return HealthConnectResult.notInstalled;
    }
    final types = [..._readTypes, ..._writeTypes];
    final access = [
      for (final _ in _readTypes) HealthDataAccess.READ,
      for (final _ in _writeTypes) HealthDataAccess.READ_WRITE,
    ];
    final ok = await _health.requestAuthorization(types, permissions: access);
    await _setConnected(ok);
    return ok ? HealthConnectResult.connected : HealthConnectResult.denied;
  }

  /// Revokes the permissions and stops using Health Connect.
  Future<void> disconnect() async {
    try {
      await _configure();
      await _health.revokePermissions();
    } catch (e) {
      debugPrint('No se pudieron revocar los permisos de Health Connect: $e');
    }
    await _setConnected(false);
  }

  /// Saves the connected flag and refreshes today's energy.
  Future<void> _setConnected(bool v) async {
    state = v;
    await ref.read(prefsProvider).setBool(_connectedKey, v);
    ref.invalidate(todayEnergyProvider);
  }

  /// Saves a finished workout as a strength session with its calories.
  Future<void> saveWorkout(WorkoutLog log, {required DateTime start}) async {
    if (!state) return;
    try {
      await _configure();
      await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.STRENGTH_TRAINING,
        start: start,
        end: log.date,
        totalEnergyBurned: log.kcal,
        title: 'FitStreak · ${log.dayName}',
        recordingMethod: RecordingMethod.manual,
      );
      ref.invalidate(todayEnergyProvider);
    } catch (e) {
      debugPrint('No se pudo guardar el entreno en Health Connect: $e');
    }
  }

  /// Today's data from Health Connect (null if it couldn't be read).
  /// `eatenKcal` is null when no food app wrote any meal today.
  Future<({int steps, int activeKcal, int totalKcal, int? eatenKcal})?> readToday() async {
    if (!state) return null;
    try {
      await _configure();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(midnight, now) ?? 0;
      final points = await _health.getHealthDataFromTypes(
        types: const [
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.TOTAL_CALORIES_BURNED,
          HealthDataType.NUTRITION,
        ],
        startTime: midnight,
        endTime: now,
      );
      double active = 0, total = 0, eaten = 0;
      var anyFood = false;
      for (final p in points) {
        final v = p.value;
        switch (p.type) {
          case HealthDataType.ACTIVE_ENERGY_BURNED when v is NumericHealthValue:
            active += v.numericValue;
          case HealthDataType.TOTAL_CALORIES_BURNED when v is NumericHealthValue:
            total += v.numericValue;
          case HealthDataType.NUTRITION when v is NutritionHealthValue:
            anyFood = true;
            eaten += v.calories ?? 0;
          default:
        }
      }
      return (
        steps: steps,
        activeKcal: active.round(),
        totalKcal: total.round(),
        eatenKcal: anyFood ? eaten.round() : null,
      );
    } catch (e) {
      debugPrint('No se pudo leer Health Connect: $e');
      return null;
    }
  }
}

/// Whether Health Connect is connected.
final healthProvider = NotifierProvider<HealthNotifier, bool>(HealthNotifier.new);

/// What the "today's energy" card shows.
class TodayEnergy {
  /// Creates today's figures.
  const TodayEnergy({
    required this.goalKcal,
    required this.burnedKcal,
    required this.fromHealth,
    this.eatenKcal,
    this.steps,
  });

  /// What to eat today for the goal.
  final int goalKcal;

  /// Today's active calories (watch + workouts, or FitStreak workouts only).
  final int burnedKcal;

  /// Eaten according to Fitia or another food app (null = no data).
  final int? eatenKcal;

  /// Today's steps (null without Health Connect).
  final int? steps;

  /// True when the figures come from Health Connect.
  final bool fromHealth;

  /// Calories left to reach the goal (negative when over; null without
  /// food data).
  int? get leftKcal => eatenKcal == null ? null : goalKcal - eatenKcal!;
}

/// Today's goal, burned and eaten calories and steps.
final todayEnergyProvider = FutureProvider.autoDispose<TodayEnergy?>((ref) async {
  final profile = ref.watch(profileProvider);
  if (profile == null) return null;
  final logs = ref.watch(workoutLogsProvider);
  ref.watch(healthProvider);
  final goal = dailyGoalKcal(profile);

  final now = DateTime.now();
  final ownKcal = logs
      .where((l) => dateOnly(l.date) == dateOnly(now))
      .fold<int>(0, (a, l) => a + (l.kcal ?? workoutKcal(weightKg: profile.weightKg, durationSeconds: l.durationSeconds)));

  final hc = await ref.read(healthProvider.notifier).readToday();
  if (hc == null) return TodayEnergy(goalKcal: goal, burnedKcal: ownKcal, fromHealth: false);

  // Some watches only store the day's total (basal included): the basal part
  // elapsed so far is subtracted to keep only the active calories.
  var active = hc.activeKcal;
  if (active == 0 && hc.totalKcal > 0) {
    final elapsedDay = now.difference(DateTime(now.year, now.month, now.day)).inMinutes / 1440;
    active = (hc.totalKcal - basalKcal(profile) * elapsedDay).round().clamp(0, 1 << 30);
  }
  return TodayEnergy(
    goalKcal: goal,
    // FitStreak workouts are already in Health Connect: don't count them twice.
    burnedKcal: active > ownKcal ? active : ownKcal,
    eatenKcal: hc.eatenKcal,
    steps: hc.steps,
    fromHealth: true,
  );
});
