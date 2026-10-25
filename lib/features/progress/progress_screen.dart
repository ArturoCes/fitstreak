import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/exercise.dart';
import '../../data/exercise_repository.dart';
import '../../data/progress_state.dart';
import '../../data/progression.dart';
import '../../data/streak.dart';
import '../../ui/exercise_media.dart';
import '../../ui/theme.dart';

/// "Progreso" tab: totals, workouts per week and per-exercise progress.
class ProgressScreen extends ConsumerWidget {
  /// Creates the screen.
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(workoutLogsProvider);
    final exercises = ref.watch(exercisesProvider).value ?? const [];
    final byId = {for (final e in exercises) e.id: e};
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();

    final totalSets = logs.fold<int>(0, (a, l) => a + l.setsDone);
    final kgMoved = logs.fold<double>(
      0,
      (a, l) =>
          a +
          l.exercises.fold<double>(
            0,
            (b, e) => b + e.sets.fold<double>(0, (c, s) => c + s.reps * (s.weightKg ?? 0)),
          ),
    );
    final perWeek = workoutsPerWeek(logs, now);

    // Exercises with records, most recent first.
    final lastDate = <String, DateTime>{};
    for (final l in logs) {
      for (final e in l.exercises) {
        lastDate[e.exerciseId] = l.date;
      }
    }
    final tracked = lastDate.keys.where(byId.containsKey).toList()
      ..sort((a, b) => lastDate[b]!.compareTo(lastDate[a]!));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text('Tu progreso', style: text.headlineMedium),
            const SizedBox(height: 16),
            Row(
              spacing: 10,
              children: [
                _Stat(value: '${logs.length}', label: 'Entrenos'),
                _Stat(value: '${perWeek.last}', label: 'Esta semana'),
                _Stat(value: '$totalSets', label: 'Series'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              spacing: 10,
              children: [
                _Stat(value: '${_compact(kgMoved)} kg', label: 'Peso total movido', wide: true),
              ],
            ),
            const SizedBox(height: 20),
            Text('Entrenos por semana', style: text.titleMedium),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 20, 16, 8),
                child: SizedBox(height: 170, child: _WeeksChart(perWeek: perWeek, today: now)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Tus ejercicios', style: text.titleMedium),
            const SizedBox(height: 6),
            if (tracked.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Termina tu primer entreno apuntando repeticiones y peso para ver aquí tu evolución.',
                    style: text.bodyMedium,
                  ),
                ),
              ),
            for (final id in tracked) _ExerciseTile(exercise: byId[id]!, points: progressFor(logs, id)),
          ],
        ),
      ),
    );
  }
}

/// Kilograms, in tonnes above 10,000 ("12.3 t").
String _compact(double v) => v >= 10000 ? '${(v / 1000).toStringAsFixed(1)} t' : formatKg(v);

/// One total (workouts, sets, kilos...).
class _Stat extends StatelessWidget {
  /// Creates the figure.
  const _Stat({required this.value, required this.label, this.wide = false});

  /// The figure.
  final String value;

  /// What it counts.
  final String label;

  /// Takes the full row width.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: text.titleLarge?.copyWith(color: AppColors.teal)),
              Text(label, style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bar chart of workouts per week.
class _WeeksChart extends StatelessWidget {
  /// Creates the chart.
  const _WeeksChart({required this.perWeek, required this.today});

  /// Workouts per week, oldest first; the last is the current week.
  final List<int> perWeek;

  /// Today, to label the weeks.
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall;
    final maxY = (perWeek.fold(0, (a, b) => a > b ? a : b) + 1).toDouble();
    final monday = addDays(today, 1 - today.weekday);
    return BarChart(
      BarChartData(
        maxY: maxY < 4 ? 4 : maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${rod.toY.toInt()} entrenos',
              const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 22,
              getTitlesWidget: (v, _) => Text('${v.toInt()}', style: muted),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                final weeksAgo = perWeek.length - 1 - v.toInt();
                if (weeksAgo == 0) return Text('Esta', style: muted);
                final d = addDays(monday, -7 * weeksAgo);
                return Text('${d.day}/${d.month}', style: muted);
              },
            ),
          ),
        ),
        barGroups: [
          for (final (i, n) in perWeek.indexed)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: n.toDouble(),
                  width: 16,
                  color: i == perWeek.length - 1 ? AppColors.orange : AppColors.teal,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// An exercise with its last session; opens its progress chart.
class _ExerciseTile extends StatelessWidget {
  /// Creates the tile.
  const _ExerciseTile({required this.exercise, required this.points});

  /// The exercise.
  final Exercise exercise;

  /// Its sessions, oldest first.
  final List<ProgressPoint> points;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final weighted = usesWeight(exercise);
    final first = points.first;
    final last = points.last;
    final String best;
    final String? delta;
    if (weighted) {
      best = 'Último: ${formatKg(last.bestWeight)} kg × ${last.bestReps}';
      final d = last.bestWeight - first.bestWeight;
      delta = points.length > 1 && d != 0 ? '${d > 0 ? '+' : ''}${formatKg(d)} kg' : null;
    } else {
      best = 'Último: ${last.bestReps} reps';
      final d = last.bestReps - first.bestReps;
      delta = points.length > 1 && d != 0 ? '${d > 0 ? '+' : ''}$d reps' : null;
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/progress/${exercise.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.square(dimension: 52, child: ExerciseMedia(exercise)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('$best · ${points.length} ${points.length == 1 ? 'sesión' : 'sesiones'}',
                        style: text.bodySmall),
                  ],
                ),
              ),
              if (delta != null)
                Text(
                  delta,
                  style: text.labelLarge?.copyWith(
                    color: delta.startsWith('+') ? AppColors.teal : AppColors.orange,
                  ),
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
