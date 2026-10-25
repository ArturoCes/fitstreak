// Duolingo-style streak adapted to training: rest days count as long as you
// don't chain more of them than your plan allows. Going over uses a freeze
// ("protector") to cover the day; with no freezes left the streak resets.

import 'dart:math';

/// [d] at midnight (time of day dropped).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// [n] calendar days after [d], at midnight. Adding `Duration(days: n)` is
/// wrong across a daylight saving change: that day lasts 23 or 25 hours and
/// the result lands at 23:00 of the previous day.
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Whole calendar days from [from] to [to]. Computed in UTC so daylight
/// saving days (23 or 25 hours) don't throw it off.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(to.year, to.month, to.day)
    .difference(DateTime.utc(from.year, from.month, from.day))
    .inDays;

/// Consecutive rest days allowed for the training days per week: the days
/// the plan leaves free (4 days → 3, so you can train Tuesday to Friday and
/// take a long weekend), and never fewer than 2.
/// 2 days → 5, 3 → 4, 4 → 3, 5-6 → 2.
int maxRestDays(int daysPerWeek) => max(7 - daysPerWeek, 2);

/// Freezes a new user starts with.
const startingFreezes = 1;

/// Most freezes that can be held at once.
const maxFreezes = 2;

/// Streak days needed to earn a freeze.
const freezeEvery = 7;

/// The user's streak: when it started, the protected rest window, freezes
/// and the trained days for the calendar. Immutable; every change returns a
/// new state.
class StreakState {
  /// Creates a streak state (empty by default).
  const StreakState({
    this.streakStart,
    this.lastWorkout,
    this.protectedUntil,
    this.freezes = startingFreezes,
    this.best = 0,
    this.freezesAwarded = 0,
    this.workoutDays = const {},
  });

  /// First day of the current streak (null = no streak).
  final DateTime? streakStart;

  /// Day of the last finished workout.
  final DateTime? lastWorkout;

  /// Last day that counts as an allowed rest (or covered by a freeze).
  final DateTime? protectedUntil;

  /// Freezes available.
  final int freezes;

  /// Longest streak ever, in days.
  final int best;

  /// Freezes earned during the current streak, so rewards aren't repeated.
  final int freezesAwarded;

  /// Trained days ("2026-10-19") for the calendar.
  final Set<String> workoutDays;

  /// Calendar key of [d] ("2026-10-19").
  static String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Whether there was a workout on [d].
  bool trainedOn(DateTime d) => workoutDays.contains(key(d));

  /// Streak length as of [today]. Today counts if you already trained or it
  /// is an allowed rest day; otherwise today is still "in play".
  int current(DateTime today) {
    final start = streakStart;
    if (start == null) return 0;
    return daysBetween(start, today) + (_todayCounts(today) ? 1 : 0);
  }

  /// Whether [today] is already covered (trained or protected).
  bool _todayCounts(DateTime today) =>
      trainedOn(today) ||
      (protectedUntil != null && !dateOnly(today).isAfter(protectedUntil!));

  /// There is a streak and, if you don't train today, tomorrow a freeze will
  /// be spent or the streak lost.
  bool atRisk(DateTime today) => streakStart != null && !_todayCounts(today);

  /// Applies what happened up to yesterday: spends freezes or breaks the
  /// streak. Idempotent: calling it several times on the same day changes
  /// nothing.
  StreakState evaluate(DateTime today) {
    if (streakStart == null || protectedUntil == null) return this;
    final yesterday = addDays(today, -1);
    var until = protectedUntil!;
    var left = freezes;
    while (yesterday.isAfter(until) && left > 0) {
      until = addDays(until, 1);
      left--;
    }
    if (yesterday.isAfter(until)) {
      return _copy(
        clearStreak: true,
        freezes: left,
        freezesAwarded: 0,
      );
    }
    return _copy(protectedUntil: until, freezes: left);
  }

  /// Applies the current rest rule to the last workout: if more days are
  /// allowed now (rule change or different days per week), the protection
  /// is extended. It is never shortened.
  StreakState withRestAllowance(int daysPerWeek) {
    final last = lastWorkout, until = protectedUntil;
    if (streakStart == null || last == null || until == null) return this;
    final allowed = addDays(last, maxRestDays(daysPerWeek));
    return allowed.isAfter(until) ? _copy(protectedUntil: allowed) : this;
  }

  /// Records a workout on [now]'s day: starts or extends the streak, opens a
  /// new protected rest window and awards a freeze every [freezeEvery] days.
  StreakState recordWorkout(DateTime now, {required int daysPerWeek}) {
    final today = dateOnly(now);
    final s = evaluate(today);
    final start = s.streakStart ?? today;
    final next = StreakState(
      streakStart: start,
      lastWorkout: today,
      protectedUntil: addDays(today, maxRestDays(daysPerWeek)),
      freezes: s.freezes,
      best: s.best,
      freezesAwarded: s.freezesAwarded,
      workoutDays: {...s.workoutDays, key(today)},
    );
    final days = next.current(today);
    final earned = days ~/ freezeEvery;
    return next._copy(
      best: days > next.best ? days : next.best,
      freezes: (next.freezes + (earned - next.freezesAwarded)).clamp(0, maxFreezes),
      freezesAwarded: earned,
    );
  }

  /// Copy with the given fields replaced; [clearStreak] ends the streak.
  StreakState _copy({
    bool clearStreak = false,
    DateTime? protectedUntil,
    int? freezes,
    int? best,
    int? freezesAwarded,
  }) =>
      StreakState(
        streakStart: clearStreak ? null : streakStart,
        lastWorkout: lastWorkout,
        protectedUntil: clearStreak ? null : (protectedUntil ?? this.protectedUntil),
        freezes: freezes ?? this.freezes,
        best: best ?? this.best,
        freezesAwarded: freezesAwarded ?? this.freezesAwarded,
        workoutDays: workoutDays,
      );

  /// Serializes the state for preferences.
  Map<String, dynamic> toJson() => {
        'streakStart': streakStart?.toIso8601String(),
        'lastWorkout': lastWorkout?.toIso8601String(),
        'protectedUntil': protectedUntil?.toIso8601String(),
        'freezes': freezes,
        'best': best,
        'freezesAwarded': freezesAwarded,
        'workoutDays': workoutDays.toList(),
      };

  /// Reads a state written by [toJson].
  factory StreakState.fromJson(Map<String, dynamic> j) {
    DateTime? d(String k) => j[k] == null ? null : DateTime.parse(j[k] as String);
    return StreakState(
      streakStart: d('streakStart'),
      lastWorkout: d('lastWorkout'),
      protectedUntil: d('protectedUntil'),
      freezes: j['freezes'] as int,
      best: j['best'] as int,
      freezesAwarded: j['freezesAwarded'] as int? ?? 0,
      workoutDays: {...(j['workoutDays'] as List).cast<String>()},
    );
  }
}

/// A completed set: reps (or seconds for timed holds) and weight.
class SetLog {
  /// Creates a set record.
  const SetLog({required this.reps, this.weightKg});

  /// Reps done, or seconds held for timed exercises.
  final int reps;

  /// Weight in kg; null for unloaded exercises (bodyweight, bands...).
  final double? weightKg;

  /// Serializes the set (`kg` only when loaded).
  Map<String, dynamic> toJson() => {'reps': reps, if (weightKg != null) 'kg': weightKg};

  /// Reads a set written by [toJson].
  factory SetLog.fromJson(Map<String, dynamic> j) =>
      SetLog(reps: j['reps'] as int, weightKg: (j['kg'] as num?)?.toDouble());
}

/// The sets of one exercise within a workout.
class ExerciseLog {
  /// Creates an exercise record.
  const ExerciseLog({required this.exerciseId, required this.sets});

  /// Catalog (or custom) exercise id.
  final String exerciseId;

  /// Completed sets, in order.
  final List<SetLog> sets;

  /// Serializes the record.
  Map<String, dynamic> toJson() => {
        'id': exerciseId,
        'sets': [for (final s in sets) s.toJson()],
      };

  /// Reads a record written by [toJson].
  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        exerciseId: j['id'] as String,
        sets: [for (final s in j['sets'] as List) SetLog.fromJson(s as Map<String, dynamic>)],
      );
}

/// Record of a finished workout.
class WorkoutLog {
  /// Creates a workout record.
  const WorkoutLog({
    required this.date,
    required this.dayIndex,
    required this.dayName,
    required this.setsDone,
    required this.setsTotal,
    required this.durationSeconds,
    this.exercises = const [],
    this.kcal,
  });

  /// When the workout was finished.
  final DateTime date;

  /// Index of the routine day that was trained.
  final int dayIndex;

  /// Name of that day at the time ("Push").
  final String dayName;

  /// Sets completed.
  final int setsDone;

  /// Sets planned.
  final int setsTotal;

  /// Active time, pauses excluded.
  final int durationSeconds;

  /// Estimated active calories (null in workouts saved before they were
  /// calculated).
  final int? kcal;

  /// Sets done per exercise (empty in workouts saved before reps and weight
  /// were recorded).
  final List<ExerciseLog> exercises;

  /// Serializes the record.
  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'dayIndex': dayIndex,
        'dayName': dayName,
        'setsDone': setsDone,
        'setsTotal': setsTotal,
        'durationSeconds': durationSeconds,
        if (kcal != null) 'kcal': kcal,
        'exercises': [for (final e in exercises) e.toJson()],
      };

  /// Reads a record written by [toJson].
  factory WorkoutLog.fromJson(Map<String, dynamic> j) => WorkoutLog(
        date: DateTime.parse(j['date'] as String),
        dayIndex: j['dayIndex'] as int,
        dayName: j['dayName'] as String,
        setsDone: j['setsDone'] as int,
        setsTotal: j['setsTotal'] as int,
        durationSeconds: j['durationSeconds'] as int,
        kcal: j['kcal'] as int?,
        exercises: [
          for (final e in j['exercises'] as List? ?? const [])
            ExerciseLog.fromJson(e as Map<String, dynamic>),
        ],
      );
}
