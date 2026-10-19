import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/exercise.dart';
import '../../data/exercise_repository.dart';
import '../../data/progress_state.dart';
import '../../data/progression.dart';
import '../../data/routine.dart';
import '../../data/streak.dart';
import '../../ui/exercise_media.dart';
import '../../ui/theme.dart';

/// Una serie mientras entrenas: arranca con la propuesta y se puede editar.
class _SetState {
  _SetState(SetLog plan)
      : reps = plan.reps,
        kg = plan.weightKg;

  int reps;
  double? kg;
  bool done = false;

  SetLog toLog() => SetLog(reps: reps, weightKg: kg);
}

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key, required this.dayIndex});

  final int dayIndex;

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  final _startedAt = DateTime.now();

  /// Propuesta y estado de cada ejercicio del día (por posición). Se calcula
  /// una vez al abrir para que no cambie mientras entrenas.
  List<SetPlan>? _plans;
  List<List<_SetState>>? _sets;

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

  int get _setsDone => _sets?.fold<int>(0, (a, l) => a + l.where((s) => s.done).length) ?? 0;

  void _ensurePlans(RoutineDay day, Map<String, Exercise> byId) {
    if (_plans != null) return;
    final logs = ref.read(workoutLogsProvider);
    _plans = [
      for (final item in day.items)
        planSets(item, byId[item.exerciseId]!, lastSession(logs, item.exerciseId)),
    ];
    _sets = [
      for (final p in _plans!) [for (final s in p.sets) _SetState(s)],
    ];
  }

  void _toggleSet(_SetState set, RoutineItem item, int total) {
    setState(() {
      set.done = !set.done;
      // Descanso tras cada serie, salvo al acabar el entreno.
      _restEndsAt = set.done && _setsDone < total
          ? DateTime.now().add(Duration(seconds: item.restSeconds))
          : null;
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
        exercises: [
          for (final (i, item) in day.items.indexed)
            if (_sets![i].any((s) => s.done))
              ExerciseLog(
                exerciseId: item.exerciseId,
                sets: [for (final s in _sets![i]) if (s.done) s.toLog()],
              ),
        ],
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
    if (routine == null || exercises == null || widget.dayIndex >= routine.days.length) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final day = routine.days[widget.dayIndex];
    final byId = {for (final e in exercises) e.id: e};
    _ensurePlans(day, byId);
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
              _ExerciseCard(
                item: item,
                exercise: byId[item.exerciseId]!,
                plan: _plans![i],
                sets: _sets![i],
                onChanged: () => setState(() {}),
                onToggle: (s) => _toggleSet(s, item, total),
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

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.item,
    required this.exercise,
    required this.plan,
    required this.sets,
    required this.onChanged,
    required this.onToggle,
  });

  final RoutineItem item;
  final Exercise exercise;
  final SetPlan plan;
  final List<_SetState> sets;
  final VoidCallback onChanged;
  final ValueChanged<_SetState> onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final complete = sets.every((s) => s.done);
    final weighted = usesWeight(exercise);
    final timed = isTimed(item);
    final last = plan.last;

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
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox.square(
                      dimension: 64,
                      // Animado mientras quedan series: recuerda el movimiento.
                      child: ExerciseMedia(exercise, animate: !complete),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise.name, style: text.titleMedium),
                        Text(
                          'Objetivo: ${item.sets} × ${item.reps} · descanso ${item.restSeconds} s',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (complete) const Icon(Icons.check_circle, color: AppColors.teal),
                ],
              ),
            ),
            if (last != null) ...[
              const SizedBox(height: 8),
              Text(
                'Última vez: ${describeSets(last.sets, timed: timed)}',
                style: text.bodySmall,
              ),
            ],
            if (plan.levelUp)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _Hint(
                  weighted
                      ? 'Completaste todas las series: sube a ${formatKg(plan.sets.first.weightKg!)} kg'
                      : 'Completaste todas las series: intenta una repetición más',
                ),
              ),
            const SizedBox(height: 8),
            for (final (i, s) in sets.indexed)
              _SetRow(
                index: i,
                set: s,
                weighted: weighted,
                timed: timed,
                kgStep: weightStep(exercise),
                onChanged: onChanged,
                onToggle: () => onToggle(s),
              ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_up, size: 18, color: AppColors.orange),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.index,
    required this.set,
    required this.weighted,
    required this.timed,
    required this.kgStep,
    required this.onChanged,
    required this.onToggle,
  });

  final int index;
  final _SetState set;
  final bool weighted;
  final bool timed;
  final double kgStep;
  final VoidCallback onChanged;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: set.done ? AppColors.teal.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: set.done ? AppColors.teal : scheme.surfaceContainerHighest,
            child: Text(
              '${index + 1}',
              style: TextStyle(fontSize: 12, color: set.done ? Colors.white : scheme.onSurface),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _Stepper(
              label: timed ? 's' : 'reps',
              value: '${set.reps}',
              onMinus: set.reps > 1 ? () => _setReps(set.reps - 1) : null,
              onPlus: () => _setReps(set.reps + 1),
              onEdit: () => _edit(context, timed ? 'Segundos' : 'Repeticiones', '${set.reps}', (v) {
                final n = int.tryParse(v);
                if (n != null && n > 0) _setReps(n);
              }),
            ),
          ),
          if (weighted) ...[
            // Separación clara entre el "+" de repeticiones y el "−" de kilos.
            Container(
              width: 1,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Theme.of(context).dividerColor,
            ),
            Expanded(
              child: _Stepper(
                label: 'kg',
                value: formatKg(set.kg ?? 0),
                onMinus: (set.kg ?? 0) > 0 ? () => _setKg((set.kg! - kgStep).clamp(0, 999)) : null,
                onPlus: () => _setKg((set.kg ?? 0) + kgStep),
                onEdit: () => _edit(context, 'Peso (kg)', formatKg(set.kg ?? 0), (v) {
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n != null && n >= 0) _setKg(n);
                }),
              ),
            ),
          ],
          IconButton(
            tooltip: set.done ? 'Desmarcar serie' : 'Marcar serie hecha',
            onPressed: onToggle,
            icon: Icon(
              set.done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: set.done ? AppColors.teal : scheme.outline,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  void _setReps(int v) {
    set.reps = v;
    onChanged();
  }

  void _setKg(double v) {
    set.kg = v;
    onChanged();
  }

  Future<void> _edit(
    BuildContext context,
    String title,
    String initial,
    ValueChanged<String> onSave,
  ) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text('Guardar')),
        ],
      ),
    );
    if (value != null) onSave(value);
  }
}

/// "–  10 reps  +": botones para ajustar rápido y toque en el número para
/// escribirlo directamente.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.onEdit,
  });

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundButton(icon: Icons.remove, onTap: onMinus),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Text(value, style: text.titleMedium, maxLines: 1),
                  Text(label, style: text.labelSmall?.copyWith(color: AppColors.muted)),
                ],
              ),
            ),
          ),
        ),
        _RoundButton(icon: Icons.add, onTap: onPlus),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 30,
          child: Icon(icon, size: 18, color: onTap == null ? scheme.outline : scheme.onSurface),
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
            Text('Descanso ${_mmss(remaining)}', style: Theme.of(context).textTheme.titleMedium),
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
