import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/exercise_repository.dart';
import '../../data/progression.dart';
import '../../data/routine.dart';
import '../../data/app_state.dart';
import '../../data/summary.dart';
import '../../data/summary_state.dart';
import '../../ui/energy_card.dart';
import '../../ui/theme.dart';

/// "Tu resumen": today (calories, workout, steps, streak) and the week
/// (workouts, volume, records). Everything can be listened to; with [speak]
/// it reads itself on opening (from the icon shortcut, voice or a
/// notification).
class SummaryScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SummaryScreen({super.key, this.week = false, this.speak = false});

  /// Open on the week tab.
  final bool week;

  /// Read the summary aloud as soon as it is ready.
  final bool speak;

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

/// Tabs and text-to-speech.
class _SummaryScreenState extends ConsumerState<SummaryScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this, initialIndex: widget.week ? 1 : 0);
  final _tts = FlutterTts();
  bool _speaking = false;
  bool _autoSpoken = false;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('es-ES').catchError((_) => null);
    _tts.setSpeechRate(kIsWeb ? 1.0 : 0.5).catchError((_) => null);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) _stop();
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _tabs.dispose();
    super.dispose();
  }

  /// Reads [text] aloud in Spanish.
  Future<void> _say(String text) async {
    await _tts.stop();
    setState(() => _speaking = true);
    try {
      await _tts.speak(text);
    } catch (_) {
      if (mounted) setState(() => _speaking = false);
    }
  }

  /// Stops reading.
  Future<void> _stop() async {
    await _tts.stop();
    if (mounted) setState(() => _speaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(dailySummaryProvider).value;
    final week = ref.watch(weekSummaryProvider).value;
    final current = _tabs.index == 0 ? today : week;

    // When opened with "read it to me", as soon as the text is ready.
    if (widget.speak && !_autoSpoken && current != null) {
      _autoSpoken = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _say(current));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu resumen'),
        bottom: TabBar(
          controller: _tabs,
          onTap: (_) => setState(() {}),
          tabs: const [Tab(text: 'Hoy'), Tab(text: 'Semana')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _TodayTab(text: today),
          _WeekTab(text: week),
        ],
      ),
      floatingActionButton: current == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _speaking ? _stop : () => _say(current),
              icon: Icon(_speaking ? Icons.stop_rounded : Icons.volume_up_rounded),
              label: Text(_speaking ? 'Parar' : 'Escuchar'),
            ),
    );
  }
}

/// The text that is read, visible in case you don't want sound.
class _SpokenCard extends StatelessWidget {
  /// Creates the card (a progress bar while [text] is null).
  const _SpokenCard(this.text);

  /// The summary text.
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.record_voice_over_outlined, color: AppColors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: text == null
                  ? const LinearProgressIndicator()
                  : Text(text!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Hoy" tab: energy card and today's text.
class _TodayTab extends StatelessWidget {
  /// Creates the tab.
  const _TodayTab({required this.text});

  /// Today's summary text.
  final String? text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 96 + MediaQuery.paddingOf(context).bottom),
      children: [
        const EnergyCard(),
        const SizedBox(height: 8),
        _SpokenCard(text),
      ],
    );
  }
}

/// "Semana" tab: workouts vs plan, totals, records and the week's text.
class _WeekTab extends ConsumerWidget {
  /// Creates the tab.
  const _WeekTab({required this.text});

  /// The week's summary text.
  final String? text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(weekReportProvider);
    final exercises = ref.watch(exercisesProvider).value ?? const [];
    final routine = ref.watch(routineProvider);
    final names = {
      for (final e in exercises) e.id: e.name,
      for (final RoutineDay d in routine?.days ?? const []) for (final i in d.items) i.exerciseId: i.slot,
    };
    final t = Theme.of(context).textTheme;
    if (r == null) return const SizedBox.shrink();
    final progress = r.planned == 0 ? 0.0 : (r.workouts / r.planned).clamp(0.0, 1.0);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 96 + MediaQuery.paddingOf(context).bottom),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Entrenos', style: t.titleMedium),
                    const Spacer(),
                    Text('${r.workouts} de ${r.planned}', style: t.titleMedium?.copyWith(color: AppColors.teal)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: progress, minHeight: 10),
                ),
                if (r.previousWorkouts > 0) ...[
                  const SizedBox(height: 6),
                  Text('La semana pasada: ${r.previousWorkouts}', style: t.bodySmall),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.9,
          children: [
            _Tile(Icons.repeat, 'Series', '${r.sets}'),
            _Tile(Icons.timer_outlined, 'Tiempo', spokenDuration(r.seconds).replaceAll(' minutos', ' min')),
            _Tile(Icons.fitness_center, 'Kilos movidos', thousands(r.volumeKg.round()),
                sub: r.previousVolumeKg > 0 ? _delta(r.volumeKg, r.previousVolumeKg) : null),
            _Tile(Icons.local_fire_department_outlined, 'Kcal entrenando', thousands(r.kcal)),
          ],
        ),
        if (r.records.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('🏆 Récords de la semana', style: t.titleMedium),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                for (final p in r.records)
                  ListTile(
                    leading: const Icon(Icons.emoji_events_outlined, color: AppColors.orange),
                    title: Text(names[p.exerciseId] ?? p.exerciseId),
                    trailing: Text('${formatKg(p.kg)} kg × ${p.reps}', style: t.titleSmall),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _SpokenCard(text),
      ],
    );
  }

  /// Percentage change vs last week ("+5 % vs semana pasada").
  static String _delta(double now, double before) {
    final pct = ((now - before) / before * 100).round();
    return pct >= 0 ? '+$pct % vs semana pasada' : '$pct % vs semana pasada';
  }
}

/// One weekly total.
class _Tile extends StatelessWidget {
  /// Creates the tile.
  const _Tile(this.icon, this.label, this.value, {this.sub});

  /// Icon next to the label.
  final IconData icon;

  /// What it counts.
  final String label;

  /// The figure.
  final String value;

  /// Optional comparison line.
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.teal),
                const SizedBox(width: 6),
                Expanded(child: Text(label, style: t.labelMedium?.copyWith(color: AppColors.muted))),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: t.titleLarge),
            ),
            if (sub != null) Text(sub!, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
