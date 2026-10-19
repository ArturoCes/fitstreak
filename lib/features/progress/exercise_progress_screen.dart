import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exercise_repository.dart';
import '../../data/progress_state.dart';
import '../../data/progression.dart';
import '../../ui/exercise_media.dart';
import '../../ui/theme.dart';

enum _Metric {
  weight('Peso máx.', 'kg'),
  oneRm('1RM estimado', 'kg'),
  reps('Repeticiones', 'reps'),
  volume('Volumen', '');

  const _Metric(this.label, this.unit);
  final String label;
  final String unit;
}

class ExerciseProgressScreen extends ConsumerStatefulWidget {
  const ExerciseProgressScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ExerciseProgressScreen> createState() => _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends ConsumerState<ExerciseProgressScreen> {
  _Metric? _metric;

  @override
  Widget build(BuildContext context) {
    final exercise = ref.watch(exerciseByIdProvider(widget.id)).value;
    final logs = ref.watch(workoutLogsProvider);
    if (exercise == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final points = progressFor(logs, widget.id);
    final weighted = usesWeight(exercise);
    final metrics = weighted
        ? const [_Metric.weight, _Metric.oneRm, _Metric.volume]
        : const [_Metric.reps, _Metric.volume];
    final metric = _metric ?? metrics.first;
    final text = Theme.of(context).textTheme;

    double valueOf(ProgressPoint p) => switch (metric) {
          _Metric.weight => p.bestWeight,
          _Metric.oneRm => p.estimated1RM,
          _Metric.reps => p.bestReps.toDouble(),
          _Metric.volume => p.volume,
        };

    return Scaffold(
      appBar: AppBar(title: const Text('Progreso')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox.square(dimension: 64, child: ExerciseMedia(exercise, animate: true)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(exercise.name, style: text.titleLarge)),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<_Metric>(
            showSelectedIcon: false,
            segments: [for (final m in metrics) ButtonSegment(value: m, label: Text(m.label))],
            selected: {metric},
            onSelectionChanged: (s) => setState(() => _metric = s.first),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 20, 8),
              child: SizedBox(
                height: 220,
                child: points.isEmpty
                    ? const Center(child: Text('Aún no hay sesiones registradas'))
                    : _LineChart(
                        values: [for (final p in points) valueOf(p)],
                        dates: [for (final p in points) p.date],
                        unit: metric.unit,
                      ),
              ),
            ),
          ),
          if (metric == _Metric.oneRm)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Estimación del peso máximo que podrías levantar una vez, calculada con tus series '
                '(fórmula de Epley). Sirve para comparar sesiones con distintas repeticiones.',
                style: text.bodySmall,
              ),
            ),
          const SizedBox(height: 20),
          Text('Historial', style: text.titleMedium),
          for (final p in points.reversed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${p.date.day}/${p.date.month}/${p.date.year}'),
              subtitle: Text(describeSets(p.sets)),
            ),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.values, required this.dates, required this.unit});

  final List<double> values;
  final List<DateTime> dates;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall;
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = maxY == minY ? (maxY == 0 ? 1 : maxY * 0.1) : (maxY - minY) * 0.15;
    // Con muchas sesiones, etiqueta solo algunas fechas para que no se pisen.
    final every = (values.length / 5).ceil().clamp(1, 1000);

    return LineChart(
      LineChartData(
        minY: (minY - pad).clamp(0, double.infinity).toDouble(),
        maxY: maxY + pad,
        minX: 0,
        maxX: (values.length - 1).toDouble().clamp(1, double.infinity),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${formatKg(s.y)} $unit\n${dates[s.x.toInt()].day}/${dates[s.x.toInt()].month}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                ),
            ],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, meta) =>
                  v == meta.min || v == meta.max ? const SizedBox.shrink() : Text(formatKg(v), style: muted),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 24,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= dates.length || i % every != 0 || v != i.toDouble()) {
                  return const SizedBox.shrink();
                }
                return Text('${dates[i].day}/${dates[i].month}', style: muted);
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (final (i, v) in values.indexed) FlSpot(i.toDouble(), v)],
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppColors.teal,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.teal.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}
