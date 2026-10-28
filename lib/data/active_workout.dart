import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import 'energy.dart';
import 'health_state.dart';
import 'exercise_repository.dart';
import 'progress_state.dart';
import 'progression.dart';
import 'routine.dart';
import 'streak.dart';

/// One set of the workout in progress: what is proposed or what the user
/// logged.
@immutable
class SetEntry {
  /// Creates a set entry.
  const SetEntry({required this.reps, this.kg, this.done = false});

  /// Reps (or seconds for timed holds).
  final int reps;

  /// Weight in kg (null when unloaded).
  final double? kg;

  /// Whether the set has been logged.
  final bool done;

  /// Copy with the given fields replaced.
  SetEntry copyWith({int? reps, double? kg, bool? done}) =>
      SetEntry(reps: reps ?? this.reps, kg: kg ?? this.kg, done: done ?? this.done);

  /// The entry as a history record.
  SetLog toLog() => SetLog(reps: reps, weightKg: kg);

  /// Serializes the entry.
  Map<String, dynamic> toJson() => {'reps': reps, 'kg': kg, 'done': done};

  /// Reads an entry written by [toJson].
  factory SetEntry.fromJson(Map<String, dynamic> j) => SetEntry(
        reps: j['reps'] as int,
        kg: (j['kg'] as num?)?.toDouble(),
        done: j['done'] as bool,
      );
}

/// A workout in progress. It keeps a copy of the day's exercises so that
/// regenerating the routine halfway doesn't break it.
@immutable
class ActiveWorkout {
  /// Creates the state of a workout.
  const ActiveWorkout({
    required this.dayIndex,
    required this.dayName,
    required this.items,
    required this.sets,
    required this.startedAt,
    this.pausedTotal = Duration.zero,
    this.pausedAt,
    this.exercise = 0,
    this.restEndsAt,
    this.restTotal = 0,
    this.restRemainingOnPause,
  });

  /// Index of the routine day being trained.
  final int dayIndex;

  /// Name of that day.
  final String dayName;

  /// The day's exercises (copied when the workout started).
  final List<RoutineItem> items;

  /// Sets per exercise, in the same order as [items].
  final List<List<SetEntry>> sets;

  /// When the workout started.
  final DateTime startedAt;

  /// Total time spent paused.
  final Duration pausedTotal;

  /// When the current pause started; non-null while paused.
  final DateTime? pausedAt;

  /// Exercise being shown.
  final int exercise;

  /// When the current rest ends (null = not resting).
  final DateTime? restEndsAt;

  /// Length of the current rest in seconds, for the progress ring.
  final int restTotal;

  /// Rest seconds left when the workout was paused.
  final int? restRemainingOnPause;

  /// Whether the workout is paused.
  bool get paused => pausedAt != null;

  /// Active time at [now], pauses excluded.
  Duration elapsed(DateTime now) {
    final d = (pausedAt ?? now).difference(startedAt) - pausedTotal;
    return d.isNegative ? Duration.zero : d;
  }

  /// Rest seconds left at [now] (null when not resting).
  int? restLeft(DateTime now) {
    if (paused) return restRemainingOnPause;
    final end = restEndsAt;
    if (end == null) return null;
    final left = end.difference(now).inMilliseconds / 1000;
    return left <= 0 ? null : left.ceil();
  }

  /// Sets logged so far.
  int get setsDone => sets.fold(0, (a, l) => a + l.where((s) => s.done).length);

  /// Sets planned in total.
  int get setsTotal => sets.fold(0, (a, l) => a + l.length);

  /// Whether every set has been logged.
  bool get allDone => setsDone == setsTotal;

  /// Pending set of the exercise shown (-1 when all are done).
  int get currentSet => sets[exercise].indexWhere((s) => !s.done);

  /// Whether every set of exercise [i] is done.
  bool exerciseDone(int i) => sets[i].every((s) => s.done);

  /// Copy with the given fields replaced. Nullable fields take a function so
  /// they can be set to null.
  ActiveWorkout copyWith({
    List<List<SetEntry>>? sets,
    Duration? pausedTotal,
    DateTime? Function()? pausedAt,
    int? exercise,
    DateTime? Function()? restEndsAt,
    int? restTotal,
    int? Function()? restRemainingOnPause,
  }) =>
      ActiveWorkout(
        dayIndex: dayIndex,
        dayName: dayName,
        items: items,
        sets: sets ?? this.sets,
        startedAt: startedAt,
        pausedTotal: pausedTotal ?? this.pausedTotal,
        pausedAt: pausedAt != null ? pausedAt() : this.pausedAt,
        exercise: exercise ?? this.exercise,
        restEndsAt: restEndsAt != null ? restEndsAt() : this.restEndsAt,
        restTotal: restTotal ?? this.restTotal,
        restRemainingOnPause:
            restRemainingOnPause != null ? restRemainingOnPause() : this.restRemainingOnPause,
      );

  /// Serializes the workout so it survives closing the app.
  Map<String, dynamic> toJson() => {
        'dayIndex': dayIndex,
        'dayName': dayName,
        'items': [for (final i in items) i.toJson()],
        'sets': [
          for (final l in sets) [for (final s in l) s.toJson()],
        ],
        'startedAt': startedAt.toIso8601String(),
        'pausedTotalMs': pausedTotal.inMilliseconds,
        'pausedAt': pausedAt?.toIso8601String(),
        'exercise': exercise,
        'restEndsAt': restEndsAt?.toIso8601String(),
        'restTotal': restTotal,
        'restRemainingOnPause': restRemainingOnPause,
      };

  /// Reads a workout written by [toJson].
  factory ActiveWorkout.fromJson(Map<String, dynamic> j) {
    DateTime? d(String k) => j[k] == null ? null : DateTime.parse(j[k] as String);
    return ActiveWorkout(
      dayIndex: j['dayIndex'] as int,
      dayName: j['dayName'] as String,
      items: [for (final i in j['items'] as List) RoutineItem.fromJson(i as Map<String, dynamic>)],
      sets: [
        for (final l in j['sets'] as List)
          [for (final s in l as List) SetEntry.fromJson(s as Map<String, dynamic>)],
      ],
      startedAt: DateTime.parse(j['startedAt'] as String),
      pausedTotal: Duration(milliseconds: j['pausedTotalMs'] as int),
      pausedAt: d('pausedAt'),
      exercise: j['exercise'] as int,
      restEndsAt: d('restEndsAt'),
      restTotal: j['restTotal'] as int,
      restRemainingOnPause: j['restRemainingOnPause'] as int?,
    );
  }
}

const _activeKey = 'active_workout';

/// The workout in progress and every action on it. Each change is saved, and
/// the ongoing notification and the rest-end chime are kept in sync.
class ActiveWorkoutNotifier extends Notifier<ActiveWorkout?> {
  Timer? _restTimer;

  /// Restores a workout left in progress (e.g. after the app was closed).
  @override
  ActiveWorkout? build() {
    ref.onDispose(() => _restTimer?.cancel());
    final raw = ref.read(prefsProvider).getString(_activeKey);
    if (raw == null) return null;
    try {
      final w = ActiveWorkout.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      Future.microtask(() => _afterChange(w));
      return w;
    } catch (e) {
      debugPrint('Entreno guardado ilegible, se descarta: $e');
      return null;
    }
  }

  /// Starts routine day [dayIndex], prefilled with last time's sets. Does
  /// nothing if a workout is already in progress.
  Future<void> start(int dayIndex) async {
    if (state != null) return;
    final day = ref.read(routineProvider)!.days[dayIndex];
    final exercises = await ref.read(exercisesProvider.future);
    final byId = {for (final e in exercises) e.id: e};
    final logs = ref.read(workoutLogsProvider);
    final items = [for (final i in day.items) if (byId.containsKey(i.exerciseId)) i];
    _set(ActiveWorkout(
      dayIndex: dayIndex,
      dayName: day.name,
      items: items,
      sets: [
        for (final item in items)
          [
            for (final s in planSets(item, byId[item.exerciseId]!, lastSession(logs, item.exerciseId, dayName: day.name)).sets)
              SetEntry(reps: s.reps, kg: s.weightKg),
          ],
      ],
      startedAt: DateTime.now(),
    ));
    unawaited(ref.read(notificationsProvider).requestPermission().catchError((_) => false));
  }

  /// Changes what will be logged for a set (pending or already done).
  void updateSet(int exercise, int set, {int? reps, double? kg}) {
    final w = state;
    if (w == null) return;
    _set(w.copyWith(sets: _replace(w.sets, exercise, set, w.sets[exercise][set].copyWith(reps: reps, kg: kg))));
  }

  /// Logs the current set, starts the rest and moves on to what's next.
  void logCurrent() {
    final w = state;
    if (w == null || w.paused) return;
    final set = w.currentSet;
    if (set < 0) return;
    var sets = _replace(w.sets, w.exercise, set, w.sets[w.exercise][set].copyWith(done: true));
    var next = w.copyWith(sets: sets);

    // If this exercise is finished, jump to the next pending one.
    if (next.exerciseDone(w.exercise)) {
      final pending = _nextPending(next, from: w.exercise);
      if (pending != null) next = next.copyWith(exercise: pending);
    }
    final rest = w.items[w.exercise].restSeconds;
    next = next.allDone
        ? next.copyWith(restEndsAt: () => null)
        : next.copyWith(restEndsAt: () => DateTime.now().add(Duration(seconds: rest)), restTotal: rest);
    _set(next);
  }

  /// Un-logs a set so it can be repeated.
  void undoSet(int exercise, int set) {
    final w = state;
    if (w == null) return;
    _set(w.copyWith(
      sets: _replace(w.sets, exercise, set, w.sets[exercise][set].copyWith(done: false)),
      exercise: exercise,
    ));
  }

  /// Shows exercise [exercise].
  void goTo(int exercise) {
    final w = state;
    if (w == null || exercise < 0 || exercise >= w.items.length) return;
    _set(w.copyWith(exercise: exercise));
  }

  /// Adds (or with a negative value removes) [seconds] to the current rest.
  void shiftRest(int seconds) {
    final w = state;
    final end = w?.restEndsAt;
    if (w == null || end == null || w.paused) return;
    final next = end.add(Duration(seconds: seconds));
    _set(next.isAfter(DateTime.now())
        ? w.copyWith(restEndsAt: () => next, restTotal: w.restTotal + (seconds > 0 ? seconds : 0))
        : w.copyWith(restEndsAt: () => null));
  }

  /// Ends the current rest now.
  void skipRest() {
    final w = state;
    if (w == null) return;
    _set(w.copyWith(restEndsAt: () => null, restRemainingOnPause: () => null));
  }

  /// Pauses the clock and the rest.
  void pause() {
    final w = state;
    if (w == null || w.paused) return;
    final now = DateTime.now();
    _set(w.copyWith(pausedAt: () => now, restRemainingOnPause: () => w.restLeft(now)));
  }

  /// Resumes after a pause, continuing the rest where it was.
  void resume() {
    final w = state;
    final pausedAt = w?.pausedAt;
    if (w == null || pausedAt == null) return;
    final now = DateTime.now();
    final left = w.restRemainingOnPause;
    _set(w.copyWith(
      pausedTotal: w.pausedTotal + now.difference(pausedAt),
      pausedAt: () => null,
      restEndsAt: () => left == null ? null : now.add(Duration(seconds: left)),
      restRemainingOnPause: () => null,
    ));
  }

  /// Saves the workout (it counts for the streak), sends it to Health
  /// Connect and closes it. Returns the saved record.
  Future<WorkoutLog?> finish() async {
    final w = state;
    if (w == null) return null;
    final now = DateTime.now();
    final duration = w.elapsed(now).inSeconds;
    final weight = ref.read(profileProvider)?.weightKg;
    final log = WorkoutLog(
      date: now,
      kcal: weight == null ? null : workoutKcal(weightKg: weight, durationSeconds: duration),
      dayIndex: w.dayIndex,
      dayName: w.dayName,
      setsDone: w.setsDone,
      setsTotal: w.setsTotal,
      durationSeconds: duration,
      exercises: [
        for (final (i, item) in w.items.indexed)
          if (w.sets[i].any((s) => s.done))
            ExerciseLog(
              exerciseId: item.exerciseId,
              sets: [for (final s in w.sets[i]) if (s.done) s.toLog()],
            ),
      ],
    );
    _set(null);
    await ref.read(streakProvider.notifier).completeWorkout(log);
    // To Health Connect (and from there to Fitia, Samsung Health...) if linked.
    unawaited(ref.read(healthProvider.notifier).saveWorkout(log, start: now.subtract(Duration(seconds: duration))));
    return log;
  }

  /// Discards the workout without saving it.
  void abandon() => _set(null);

  /// [sets] with set [set] of exercise [ex] replaced by [value].
  static List<List<SetEntry>> _replace(List<List<SetEntry>> sets, int ex, int set, SetEntry value) => [
        for (final (i, l) in sets.indexed)
          i != ex ? l : [for (final (j, s) in l.indexed) j == set ? value : s],
      ];

  /// The next exercise after [from] with pending sets (wrapping around).
  static int? _nextPending(ActiveWorkout w, {required int from}) {
    for (var k = 1; k <= w.items.length; k++) {
      final i = (from + k) % w.items.length;
      if (!w.exerciseDone(i)) return i;
    }
    return null;
  }

  /// Applies and saves [w] (null ends the workout) and syncs notifications.
  void _set(ActiveWorkout? w, {bool restJustEnded = false}) {
    state = w;
    final prefs = ref.read(prefsProvider);
    if (w == null) {
      prefs.remove(_activeKey);
    } else {
      prefs.setString(_activeKey, jsonEncode(w.toJson()));
    }
    _afterChange(w, restJustEnded: restJustEnded);
  }

  /// End of the rest scheduled with the system (null = none).
  DateTime? _scheduledRestEnd;

  /// Whether the system will ring the chime on time; if not (no exact alarm
  /// permission), the app's own timer shows it.
  bool _restAlarmOk = false;

  /// Alerts when the rest ends and keeps the ongoing notification up to date.
  void _afterChange(ActiveWorkout? w, {bool restJustEnded = false}) {
    _restTimer?.cancel();
    final now = DateTime.now();
    final left = w?.restLeft(now);
    final resting = w != null && !w.paused && left != null;
    _syncRestAlarm(resting ? w : null, keepShown: restJustEnded);
    if (resting) {
      _restTimer = Timer(w.restEndsAt!.difference(now), () {
        HapticFeedback.heavyImpact();
        final current = state;
        if (!_restAlarmOk && current != null) {
          unawaited(ref.read(notificationsProvider).showRestEnd(body: _nextLabel(current)).catchError((_) {}));
        }
        if (current != null) _set(current.copyWith(restEndsAt: () => null), restJustEnded: true);
      });
    }
    _notify(w, restJustEnded: restJustEnded);
  }

  /// Schedules (or removes) the rest-end chime. [keepShown]: the rest just
  /// ended and the chime is ringing, so don't remove it.
  void _syncRestAlarm(ActiveWorkout? resting, {bool keepShown = false}) {
    final end = resting?.restEndsAt;
    if (end == _scheduledRestEnd) return;
    _scheduledRestEnd = end;
    _restAlarmOk = false;
    final notifications = ref.read(notificationsProvider);
    if (end == null) {
      if (!keepShown) unawaited(notifications.cancelRestEnd().catchError((_) {}));
      return;
    }
    unawaited(notifications.scheduleRestEnd(end, body: 'Siguiente: ${_nextLabel(resting!)}').then((ok) {
      if (_scheduledRestEnd == end) _restAlarmOk = ok;
    }).catchError((_) {}));
  }

  /// What's next, e.g. "Press banca · serie 2/4".
  String _nextLabel(ActiveWorkout w) {
    final exercises = ref.read(exercisesProvider).value ?? const [];
    final id = w.items[w.exercise].exerciseId;
    var name = id;
    for (final e in exercises) {
      if (e.id == id) name = e.name;
    }
    final set = w.currentSet;
    return set < 0 ? name : '$name · serie ${set + 1}/${w.sets[w.exercise].length}';
  }

  /// Shows, updates or removes the ongoing workout notification: a countdown
  /// while resting, the elapsed time otherwise.
  void _notify(ActiveWorkout? w, {bool restJustEnded = false}) {
    final notifications = ref.read(notificationsProvider);
    if (w == null) {
      unawaited(notifications.cancelWorkout().catchError((_) {}));
      return;
    }
    final now = DateTime.now();
    final what = _nextLabel(w);
    final left = w.restLeft(now);
    final String body;
    final DateTime? chronoTo;
    final bool countDown;
    if (w.paused) {
      body = 'En pausa · $what';
      chronoTo = null;
      countDown = false;
    } else if (left != null) {
      body = 'Descanso · siguiente: $what';
      chronoTo = w.restEndsAt;
      countDown = true;
    } else {
      body = restJustEnded ? '¡A por ello! $what' : what;
      chronoTo = w.startedAt.add(w.pausedTotal);
      countDown = false;
    }
    unawaited(notifications
        .showWorkout(
          title: 'Entreno en curso · ${w.dayName}',
          body: body,
          chronometerAt: chronoTo,
          countDown: countDown,
        )
        .catchError((_) {}));
  }
}

/// The workout in progress (null when there is none).
final activeWorkoutProvider = NotifierProvider<ActiveWorkoutNotifier, ActiveWorkout?>(
  ActiveWorkoutNotifier.new,
);

/// A clock that ticks every second for the on-screen timers.
final clockProvider = StreamProvider.autoDispose<DateTime>(
  (ref) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
);
