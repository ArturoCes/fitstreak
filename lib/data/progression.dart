import 'dart:math';

import 'exercise.dart';
import 'routine.dart';
import 'streak.dart';

/// Equipo con el que tiene sentido apuntar kilos.
const _weightedEquipment = {
  'barbell',
  'dumbbell',
  'kettlebells',
  'cable',
  'machine',
  'e-z curl bar',
  'medicine ball',
};

bool usesWeight(Exercise e) => _weightedEquipment.contains(e.equipmentOrBody);

/// Ejercicios estáticos (plancha...): se apuntan segundos en vez de repeticiones.
bool isTimed(RoutineItem item) => item.reps.contains('s');

/// "8-10" → (8, 10); "15" → (15, 15); "30-45 s" → (30, 45).
(int, int) repRange(String reps) {
  final nums = RegExp(r'\d+').allMatches(reps).map((m) => int.parse(m[0]!)).toList();
  if (nums.isEmpty) return (10, 10);
  return (nums.first, nums.length > 1 ? nums[1] : nums.first);
}

/// Cuánto subir cuando ya dominas el peso: poco en mancuernas y kettlebells
/// (es por mano), más en barra y máquinas.
double weightStep(Exercise e) => switch (e.equipmentOrBody) {
      'dumbbell' || 'kettlebells' || 'medicine ball' => 1,
      _ => 2.5,
    };

/// Lo que se propone para la sesión de hoy.
class SetPlan {
  const SetPlan({required this.sets, required this.last, required this.levelUp});

  final List<SetLog> sets;

  /// La última vez que hiciste este ejercicio (null si es la primera).
  final ExerciseLog? last;

  /// true si toca subir peso (o repeticiones sin carga).
  final bool levelUp;
}

/// Última sesión registrada de un ejercicio (los logs van del más antiguo al
/// más reciente).
ExerciseLog? lastSession(List<WorkoutLog> logs, String exerciseId) {
  for (final log in logs.reversed) {
    for (final e in log.exercises) {
      if (e.exerciseId == exerciseId && e.sets.isNotEmpty) return e;
    }
  }
  return null;
}

/// Propuesta para hoy: como mínimo lo que hiciste la última vez. Si en todas
/// las series llegaste al tope del rango, sube el peso (o una repetición si
/// no hay carga) y vuelve al mínimo de repeticiones.
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

  final mastered = last.sets.every((s) => s.reps >= maxReps);
  final sets = <SetLog>[];
  for (var i = 0; i < item.sets; i++) {
    final prev = last.sets[min(i, last.sets.length - 1)];
    if (weighted) {
      final prevKg = prev.weightKg ?? 0;
      sets.add(mastered && prevKg > 0
          ? SetLog(reps: minReps, weightKg: prevKg + weightStep(exercise))
          : SetLog(reps: max(prev.reps, minReps), weightKg: prevKg));
    } else {
      sets.add(SetLog(reps: mastered ? prev.reps + 1 : max(prev.reps, minReps)));
    }
  }
  final levelUp = mastered && (!weighted || (last.sets.first.weightKg ?? 0) > 0);
  return SetPlan(sets: sets, last: last, levelUp: levelUp);
}

/// Texto corto de una sesión: "10×4 kg · 10×4 kg · 8×4 kg".
String describeSets(List<SetLog> sets, {bool timed = false}) => sets
    .map((s) => s.weightKg != null && s.weightKg! > 0
        ? '${s.reps}×${formatKg(s.weightKg!)} kg'
        : timed
            ? '${s.reps} s'
            : '${s.reps} reps')
    .join(' · ');

String formatKg(double kg) => kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);

/// Un punto del gráfico de progreso de un ejercicio.
class ProgressPoint {
  const ProgressPoint({
    required this.date,
    required this.bestWeight,
    required this.bestReps,
    required this.volume,
    required this.sets,
  });

  final DateTime date;
  final double bestWeight; // 0 si no hay carga
  final int bestReps; // repeticiones de la mejor serie
  final double volume; // suma de reps × kg (o reps sin carga)
  final List<SetLog> sets;

  /// Estimación de 1RM (fórmula de Epley) para comparar sesiones con distinto
  /// número de repeticiones.
  double get estimated1RM => bestWeight * (1 + bestReps / 30);
}

List<ProgressPoint> progressFor(List<WorkoutLog> logs, String exerciseId) => [
      for (final log in logs)
        for (final e in log.exercises)
          if (e.exerciseId == exerciseId && e.sets.isNotEmpty) _point(log.date, e.sets),
    ];

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

/// Entrenos por semana (lunes a domingo) de las últimas [weeks] semanas,
/// la última es la actual.
List<int> workoutsPerWeek(List<WorkoutLog> logs, DateTime today, {int weeks = 8}) {
  final t = dateOnly(today);
  final thisMonday = t.subtract(Duration(days: t.weekday - 1));
  final counts = List.filled(weeks, 0);
  for (final log in logs) {
    final d = dateOnly(log.date);
    final weeksAgo = daysBetween(d.subtract(Duration(days: d.weekday - 1)), thisMonday) ~/ 7;
    if (weeksAgo >= 0 && weeksAgo < weeks) counts[weeks - 1 - weeksAgo]++;
  }
  return counts;
}
