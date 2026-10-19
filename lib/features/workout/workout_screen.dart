import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/exercise.dart';
import '../../data/exercise_repository.dart';
import '../../data/progress_state.dart';
import '../../data/routine.dart';
import '../../data/streak.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key, required this.dayIndex});

  final int dayIndex;

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  final _startedAt = DateTime.now();

  /// Series marcadas por ejercicio (índice del ejercicio → series hechas).
  final Map<int, Set<int>> _done = {};

  DateTime? _restEndsAt;
  Timer? _ticker;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    // Un tick por segundo para el cronómetro y el descanso.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    final end = _restEndsAt;
    if (end != null && !DateTime.now().isBefore(end)) {
      _restEndsAt = null;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }
    if (mounted) setState(() {});
  }

  int get _setsDone => _done.values.fold(0, (a, s) => a + s.length);

  void _toggleSet(int item, int set, RoutineItem ri, {required bool isLastSet}) {
    final sets = _done.putIfAbsent(item, () => {});
    setState(() {
      if (sets.remove(set)) {
        _restEndsAt = null;
      } else {
        sets.add(set);
        // Descanso tras cada serie, salvo al acabar el entreno.
        _restEndsAt =
            isLastSet ? null : DateTime.now().add(Duration(seconds: ri.restSeconds));
      }
    });
  }

  void _shiftRest(int seconds) => setState(() {
        final end = _restEndsAt;
        if (end == null) return;
        final next = end.add(Duration(seconds: seconds));
        _restEndsAt = next.isAfter(DateTime.now()) ? next : null;
      });

  Future<void> _finish(RoutineDay day, int total) async {
    if (_setsDone < total) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('¿Terminar ya?'),
          content: Text('Llevas $_setsDone de $total series. Cuenta igual para la racha.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Seguir')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Terminar')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _finishing = true);

    final streak = ref.read(streakProvider.notifier);
    final freezesBefore = ref.read(streakProvider).freezes;
    final now = DateTime.now();
    await streak.completeWorkout(
      WorkoutLog(
        date: now,
        dayIndex: widget.dayIndex,
        dayName: day.name,
        setsDone: _setsDone,
        setsTotal: total,
        durationSeconds: now.difference(_startedAt).inSeconds,
      ),
    );
    final s = ref.read(streakProvider);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => _CelebrationDialog(
        days: s.current(now),
        earnedFreeze: s.freezes > freezesBefore,
      ),
    );
    if (mounted) context.go('/');
  }

  Future<bool> _confirmExit() async {
    if (_setsDone == 0) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('¿Salir del entreno?'),
            content: const Text('Perderás las series marcadas.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Seguir')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salir')),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final routine = ref.watch(routineProvider);
    final exercises = ref.watch(exercisesProvider).value;
    if (routine == null ||
        exercises == null ||
        widget.dayIndex >= routine.days.length) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final day = routine.days[widget.dayIndex];
    final byId = {for (final e in exercises) e.id: e};
    final total = day.items.fold(0, (a, i) => a + i.sets);
    final elapsed = DateTime.now().difference(_startedAt);

    return PopScope(
      canPop: _setsDone == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(day.name),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text(_mmss(elapsed))),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: total == 0 ? 0 : _setsDone / total),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            for (final (i, item) in day.items.indexed)
              if (byId[item.exerciseId] case final ex?)
                _ExerciseSets(
                  item: item,
                  exercise: ex,
                  done: _done[i] ?? const {},
                  onToggle: (set) => _toggleSet(
                    i,
                    set,
                    item,
                    isLastSet: _setsDone + 1 == total,
                  ),
                ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _restEndsAt != null
                ? _RestBar(
                    remaining: _restEndsAt!.difference(DateTime.now()),
                    onShift: _shiftRest,
                    onSkip: () => setState(() => _restEndsAt = null),
                  )
                : FilledButton.icon(
                    onPressed: _setsDone == 0 || _finishing ? null : () => _finish(day, total),
                    icon: const Icon(Icons.flag),
                    label: Text('Terminar entreno ($_setsDone/$total)'),
                  ),
          ),
        ),
      ),
    );
  }
}

String _mmss(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class _ExerciseSets extends StatelessWidget {
  const _ExerciseSets({
    required this.item,
    required this.exercise,
    required this.done,
    required this.onToggle,
  });

  final RoutineItem item;
  final Exercise exercise;
  final Set<int> done;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final urls = exercise.imageUrls;
    final complete = done.length == item.sets;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => context.push('/exercise/${exercise.id}'),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox.square(
                      dimension: 48,
                      child: urls.isEmpty
                          ? const Icon(Icons.fitness_center)
                          : CachedNetworkImage(imageUrl: urls.first, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise.name, style: text.titleMedium),
                        Text('${item.reps} reps · descanso ${item.restSeconds} s',
                            style: text.bodySmall),
                      ],
                    ),
                  ),
                  if (complete) const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var s = 0; s < item.sets; s++)
                  FilterChip(
                    label: Text('Serie ${s + 1}'),
                    selected: done.contains(s),
                    onSelected: (_) => onToggle(s),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RestBar extends StatelessWidget {
  const _RestBar({required this.remaining, required this.onShift, required this.onSkip});

  final Duration remaining;
  final ValueChanged<int> onShift;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            const SizedBox(width: 8),
            const Icon(Icons.timer),
            const SizedBox(width: 8),
            Text('Descanso ${_mmss(remaining)}',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton(onPressed: () => onShift(-15), child: const Text('-15')),
            TextButton(onPressed: () => onShift(15), child: const Text('+15')),
            TextButton(onPressed: onSkip, child: const Text('Saltar')),
          ],
        ),
      ),
    );
  }
}

class _CelebrationDialog extends StatelessWidget {
  const _CelebrationDialog({required this.days, required this.earnedFreeze});

  final int days;
  final bool earnedFreeze;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 64)),
          Text('$days ${days == 1 ? 'día' : 'días'} de racha', style: text.headlineSmall),
          const SizedBox(height: 8),
          const Text('¡Entreno completado! Buen trabajo.', textAlign: TextAlign.center),
          if (earnedFreeze) ...[
            const SizedBox(height: 12),
            const Text('🧊 Has ganado un protector de racha', textAlign: TextAlign.center),
          ],
        ],
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Genial')),
      ],
    );
  }
}
