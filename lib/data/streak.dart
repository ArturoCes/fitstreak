// Racha estilo Duolingo adaptada a entrenar: los días de descanso cuentan
// mientras no encadenes más de los que permite tu plan. Si te pasas, un
// protector cubre el día; sin protectores, la racha vuelve a 0.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// En UTC para que el cambio de hora (días de 23 o 25 h) no descuadre.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(to.year, to.month, to.day)
    .difference(DateTime.utc(from.year, from.month, from.day))
    .inDays;

/// Descansos seguidos permitidos según los días que entrenas por semana.
/// 2 días → 4, 3 → 3, 4-6 → 2.
int maxRestDays(int daysPerWeek) => ((7 - daysPerWeek) / daysPerWeek).ceil() + 1;

const startingFreezes = 1;
const maxFreezes = 2;
const freezeEvery = 7; // días de racha para ganar un protector

class StreakState {
  const StreakState({
    this.streakStart,
    this.lastWorkout,
    this.protectedUntil,
    this.freezes = startingFreezes,
    this.best = 0,
    this.freezesAwarded = 0,
    this.workoutDays = const {},
  });

  /// Primer día de la racha actual (null = sin racha).
  final DateTime? streakStart;
  final DateTime? lastWorkout;

  /// Último día que cuenta como descanso permitido (o cubierto con protector).
  final DateTime? protectedUntil;
  final int freezes;
  final int best;

  /// Protectores ganados en la racha actual, para no repetir premios.
  final int freezesAwarded;

  /// Días entrenados ("2026-10-19"), para el calendario.
  final Set<String> workoutDays;

  static String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool trainedOn(DateTime d) => workoutDays.contains(key(d));

  /// Días de racha a fecha de [today]. Hoy suma si ya entrenaste o si es un
  /// descanso permitido; si no, hoy aún está "en juego".
  int current(DateTime today) {
    final start = streakStart;
    if (start == null) return 0;
    return daysBetween(start, today) + (_todayCounts(today) ? 1 : 0);
  }

  bool _todayCounts(DateTime today) =>
      trainedOn(today) ||
      (protectedUntil != null && !dateOnly(today).isAfter(protectedUntil!));

  /// Hay racha y, si hoy no entrenas, mañana se gasta un protector o se pierde.
  bool atRisk(DateTime today) => streakStart != null && !_todayCounts(today);

  /// Aplica lo ocurrido hasta ayer: gasta protectores o rompe la racha.
  /// Es idempotente: llamarlo varias veces el mismo día no cambia nada.
  StreakState evaluate(DateTime today) {
    if (streakStart == null || protectedUntil == null) return this;
    final yesterday = dateOnly(today).subtract(const Duration(days: 1));
    var until = protectedUntil!;
    var left = freezes;
    while (yesterday.isAfter(until) && left > 0) {
      until = until.add(const Duration(days: 1));
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

  StreakState recordWorkout(DateTime now, {required int daysPerWeek}) {
    final today = dateOnly(now);
    final s = evaluate(today);
    final start = s.streakStart ?? today;
    final next = StreakState(
      streakStart: start,
      lastWorkout: today,
      protectedUntil: today.add(Duration(days: maxRestDays(daysPerWeek))),
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

  Map<String, dynamic> toJson() => {
        'streakStart': streakStart?.toIso8601String(),
        'lastWorkout': lastWorkout?.toIso8601String(),
        'protectedUntil': protectedUntil?.toIso8601String(),
        'freezes': freezes,
        'best': best,
        'freezesAwarded': freezesAwarded,
        'workoutDays': workoutDays.toList(),
      };

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

/// Registro de un entreno terminado.
class WorkoutLog {
  const WorkoutLog({
    required this.date,
    required this.dayIndex,
    required this.dayName,
    required this.setsDone,
    required this.setsTotal,
    required this.durationSeconds,
  });

  final DateTime date;
  final int dayIndex;
  final String dayName;
  final int setsDone;
  final int setsTotal;
  final int durationSeconds;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'dayIndex': dayIndex,
        'dayName': dayName,
        'setsDone': setsDone,
        'setsTotal': setsTotal,
        'durationSeconds': durationSeconds,
      };

  factory WorkoutLog.fromJson(Map<String, dynamic> j) => WorkoutLog(
        date: DateTime.parse(j['date'] as String),
        dayIndex: j['dayIndex'] as int,
        dayName: j['dayName'] as String,
        setsDone: j['setsDone'] as int,
        setsTotal: j['setsTotal'] as int,
        durationSeconds: j['durationSeconds'] as int,
      );
}
