import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/active_workout.dart';
import '../../data/app_state.dart';
import '../../data/exercise.dart';
import '../../data/exercise_repository.dart';
import '../../data/progress_state.dart';
import '../../data/progression.dart';
import '../../data/streak.dart';
import '../../ui/exercise_media.dart';
import '../../ui/quote_card.dart';
import 'overlay_bubble.dart';
import '../../ui/theme.dart';

/// Workout one exercise at a time: log the set, rest and go on. The state
/// lives in [activeWorkoutProvider], so leaving and coming back (or closing
/// the app) loses nothing.
class WorkoutScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

/// Screen-only state: the set being edited, the hold timer, the rest view.
class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  /// Done set being corrected (null = the current one).
  int? _editing;
  int? _shownExercise;

  /// Stopwatch of timed exercises (plank...).
  DateTime? _holdStart;
  bool _holdBuzzed = false;

  bool _finishing = false;

  /// The rest shows as a small bar and the exercise animation stays below.
  /// Remembered during the workout.
  bool _restMinimized = false;

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(activeWorkoutProvider);
    ref.watch(clockProvider);
    final exercises = ref.watch(exercisesProvider).value;
    if (w == null || exercises == null) {
      if (w == null && !_finishing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/');
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_shownExercise != w.exercise) {
      _shownExercise = w.exercise;
      _editing = null;
      _holdStart = null;
    }

    final now = DateTime.now();
    final byId = {for (final e in exercises) e.id: e};
    final item = w.items[w.exercise];
    final ex = byId[item.exerciseId]!;
    final plan = planSets(item, ex, lastSession(ref.watch(workoutLogsProvider), item.exerciseId, dayName: w.dayName));
    final weighted = usesWeight(ex);
    final timed = isTimed(item);
    final maxReps = timed ? maxHoldSeconds : maxSetReps;
    final sets = w.sets[w.exercise];
    final setIndex = _editing ?? w.currentSet;
    final restLeft = w.restLeft(now);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final holdSeconds = _holdStart == null ? 0 : now.difference(_holdStart!).inSeconds;
    if (_holdStart != null && setIndex >= 0 && !_holdBuzzed && holdSeconds >= sets[setIndex].reps) {
      _holdBuzzed = true;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.close),
            onPressed: _exitDialog,
          ),
          title: Text(w.dayName),
          actions: [
            IconButton(
              tooltip: 'Minimizar',
              icon: const Icon(Icons.picture_in_picture_alt_outlined),
              onPressed: _minimize,
            ),
            IconButton(
              tooltip: w.paused ? 'Continuar' : 'Pausar',
              icon: Icon(w.paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
              onPressed: _togglePause,
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'finish') _finish();
                if (v == 'info') context.push('/exercise/${ex.id}');
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'info', child: Text('Ver cómo se hace')),
                if (w.setsDone > 0) const PopupMenuItem(value: 'finish', child: Text('Terminar y guardar')),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: w.setsTotal == 0 ? 0 : w.setsDone / w.setsTotal),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _StatsBar(
              elapsed: w.elapsed(now),
              paused: w.paused,
              setsDone: w.setsDone,
              setsTotal: w.setsTotal,
            ),
            const SizedBox(height: 12),
            _ExerciseDots(workout: w, onTap: ref.read(activeWorkoutProvider.notifier).goTo),
            const SizedBox(height: 16),
            Text(
              item.slot.toUpperCase(),
              style: text.labelMedium?.copyWith(color: AppColors.teal, letterSpacing: 0.8),
            ),
            Text(ex.name, style: text.headlineSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Pill(
                  icon: Icons.repeat,
                  label: setIndex < 0 ? 'Completado' : 'Serie ${setIndex + 1}/${sets.length}',
                  color: scheme.tertiary,
                  strong: true,
                ),
                _Pill(icon: Icons.flag_outlined, label: 'Objetivo ${item.reps}', color: AppColors.teal),
                _Pill(icon: Icons.timer_outlined, label: 'Descanso ${item.restSeconds} s', color: AppColors.muted),
                if (item.note != null) _Pill(icon: Icons.chat_bubble_outline, label: item.note!, color: AppColors.orange),
              ],
            ),
            const SizedBox(height: 14),
            if (w.paused)
              _PausedPanel(onResume: _togglePause)
            else if (restLeft != null && _editing == null && !_restMinimized)
              _RestPanel(
                left: restLeft,
                total: w.restTotal,
                next: setIndex < 0 ? null : 'Serie ${setIndex + 1} de ${sets.length}',
                onShift: ref.read(activeWorkoutProvider.notifier).shiftRest,
                onSkip: ref.read(activeWorkoutProvider.notifier).skipRest,
                onMinimize: () => setState(() => _restMinimized = true),
              )
            else ...[
              if (restLeft != null && _editing == null) ...[
                _RestBar(
                  left: restLeft,
                  total: w.restTotal,
                  onShift: ref.read(activeWorkoutProvider.notifier).shiftRest,
                  onSkip: ref.read(activeWorkoutProvider.notifier).skipRest,
                  onExpand: () => setState(() => _restMinimized = false),
                ),
                const SizedBox(height: 10),
              ],
              _MediaPanel(exercise: ex),
            ],
            if (plan.last != null) ...[
              const SizedBox(height: 12),
              Text('Última vez: ${describeSets(plan.last!.sets, timed: timed)}', style: text.bodyMedium),
            ],
            if (plan.levelUpSets case final up? when sets.any((s) => !s.done))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _levelUpHint(w.exercise, sets, plan.sets, up, weighted),
              ),
            const SizedBox(height: 16),
            if (setIndex >= 0) ...[
              if (_editing != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18, color: scheme.tertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Corrigiendo la serie ${setIndex + 1}', style: text.titleSmall),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(activeWorkoutProvider.notifier).undoSet(w.exercise, setIndex);
                          setState(() => _editing = null);
                        },
                        child: const Text('Repetirla'),
                      ),
                    ],
                  ),
                ),
              if (timed && _editing == null)
                _HoldTimer(
                  seconds: holdSeconds,
                  target: sets[setIndex].reps,
                  running: _holdStart != null,
                  onStart: w.paused
                      ? null
                      : () => setState(() {
                            _holdStart = DateTime.now();
                            _holdBuzzed = false;
                            ref.read(activeWorkoutProvider.notifier).skipRest();
                          }),
                  onStop: () => _stopHold(w.exercise, setIndex, holdSeconds),
                ),
              if (timed && _editing == null) const SizedBox(height: 12),
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: _BigStepper(
                      label: timed ? 'Segundos' : 'Repeticiones',
                      value: '${sets[setIndex].reps}',
                      onMinus: sets[setIndex].reps > 1
                          ? () => _update(w.exercise, setIndex, reps: sets[setIndex].reps - 1)
                          : null,
                      onPlus: sets[setIndex].reps < maxReps
                          ? () => _update(w.exercise, setIndex, reps: sets[setIndex].reps + 1)
                          : null,
                      onEdit: () => _editValue(
                        timed ? 'Segundos' : 'Repeticiones',
                        '${sets[setIndex].reps}',
                        maxLength: 3,
                        decimal: false,
                        (v) {
                          final n = int.tryParse(v);
                          if (n != null && n > 0) _update(w.exercise, setIndex, reps: n.clamp(1, maxReps));
                        },
                      ),
                    ),
                  ),
                  if (weighted)
                    Expanded(
                      child: _BigStepper(
                        label: 'Peso (kg)',
                        value: formatKg(sets[setIndex].kg ?? 0),
                        onMinus: (sets[setIndex].kg ?? 0) > 0
                            ? () => _update(w.exercise, setIndex,
                                kg: ((sets[setIndex].kg ?? 0) - weightStep(ex)).clamp(0, 999).toDouble())
                            : null,
                        onPlus: (sets[setIndex].kg ?? 0) < maxSetKg
                            ? () => _update(w.exercise, setIndex,
                                kg: ((sets[setIndex].kg ?? 0) + weightStep(ex)).clamp(0, maxSetKg).toDouble())
                            : null,
                        onEdit: () => _editValue('Peso (kg)', formatKg(sets[setIndex].kg ?? 0), maxLength: 5, (v) {
                          final n = double.tryParse(v.replaceAll(',', '.'));
                          if (n != null && n >= 0) _update(w.exercise, setIndex, kg: n.clamp(0, maxSetKg).toDouble());
                        }),
                      ),
                    ),
                ],
              ),
              if (plan.last case final last? when setIndex < plan.sets.length)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Esta serie la última vez: '
                    '${describeSets([last.sets[setIndex.clamp(0, last.sets.length - 1)]], timed: timed)}',
                    style: text.bodySmall,
                  ),
                ),
            ] else
              _DoneCard(allDone: w.allDone),
            const SizedBox(height: 20),
            Text('Series', style: text.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (j, s) in sets.indexed)
                  _SetChip(
                    index: j,
                    text: s.kg != null && s.kg! > 0
                        ? '${s.reps}×${formatKg(s.kg!)} kg'
                        : '${s.reps}${timed ? ' s' : ''}',
                    done: s.done,
                    selected: j == setIndex,
                    onTap: () => setState(() {
                      _editing = s.done && j != _editing ? j : null;
                      _holdStart = null;
                    }),
                  ),
              ],
            ),
            if (sets.any((s) => s.done))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Toca una serie hecha para corregirla.', style: text.bodySmall),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              spacing: 10,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Ejercicio anterior',
                  iconSize: 28,
                  onPressed: w.exercise > 0 ? () => ref.read(activeWorkoutProvider.notifier).goTo(w.exercise - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(child: _mainButton(w, setIndex, timed, holdSeconds)),
                IconButton.filledTonal(
                  tooltip: 'Ejercicio siguiente',
                  iconSize: 28,
                  onPressed: w.exercise < w.items.length - 1
                      ? () => ref.read(activeWorkoutProvider.notifier).goTo(w.exercise + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Main button: start the hold, log the set, next exercise or finish.
  Widget _mainButton(ActiveWorkout w, int setIndex, bool timed, int holdSeconds) {
    final notifier = ref.read(activeWorkoutProvider.notifier);
    final (IconData icon, String label, VoidCallback? onTap) = switch (()) {
      _ when w.paused => (Icons.play_arrow_rounded, 'Continuar', _togglePause),
      _ when _editing != null => (Icons.check, 'Guardar cambios', () => setState(() => _editing = null)),
      _ when setIndex >= 0 => (
          Icons.check_circle_outline,
          'Registrar serie',
          () {
            if (_holdStart != null) {
              notifier.updateSet(w.exercise, setIndex, reps: holdSeconds < 1 ? 1 : holdSeconds);
              _holdStart = null;
            }
            HapticFeedback.mediumImpact();
            notifier.logCurrent();
          },
        ),
      _ when w.allDone => (Icons.flag, 'Terminar entreno', _finishing ? null : _finish),
      _ => (
          Icons.skip_next_rounded,
          'Siguiente ejercicio',
          () {
            for (var k = 1; k <= w.items.length; k++) {
              final i = (w.exercise + k) % w.items.length;
              if (!w.exerciseDone(i)) return notifier.goTo(i);
            }
          },
        ),
    };
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: w.allDone && !w.paused && _editing == null ? AppColors.orange : null,
        foregroundColor: w.allDone && !w.paused && _editing == null ? AppColors.navy : null,
        textStyle: Theme.of(context).textTheme.titleMedium,
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  /// "Dominaste el rango: puedes subir a X kg" with a button that applies it
  /// to the remaining sets (and undoes it if already applied).
  Widget _levelUpHint(int exercise, List<SetEntry> sets, List<SetLog> lastTime, List<SetLog> up, bool weighted) {
    final pending = [for (final (j, s) in sets.indexed) if (!s.done && j < up.length) j];
    final applied = pending.every((j) => sets[j].reps == up[j].reps && sets[j].kg == up[j].weightKg);
    final what = weighted ? '${formatKg(up.first.weightKg!)} kg × ${up.first.reps}' : '${up.first.reps} reps';
    return _Hint(
      applied
          ? 'Aplicado: $what. ¡A por ello!'
          : weighted
              ? 'Dominaste el rango: puedes subir a $what'
              : 'Dominaste el rango: puedes intentar una repetición más',
      actionLabel: applied ? 'Deshacer' : 'Aplicar',
      onAction: () {
        final n = ref.read(activeWorkoutProvider.notifier);
        for (final j in pending) {
          final target = applied ? lastTime[j] : up[j];
          n.updateSet(exercise, j, reps: target.reps, kg: target.weightKg);
        }
      },
    );
  }

  /// Changes the reps or weight of a set.
  void _update(int exercise, int set, {int? reps, double? kg}) =>
      ref.read(activeWorkoutProvider.notifier).updateSet(exercise, set, reps: reps, kg: kg);

  /// Stops the hold timer and saves the [seconds] held as the set's reps.
  void _stopHold(int exercise, int set, int seconds) {
    setState(() => _holdStart = null);
    // A timer left running doesn't log an hour-long plank.
    if (seconds > 0) _update(exercise, set, reps: seconds.clamp(1, maxHoldSeconds));
  }

  /// Leaves without pausing. The first time it offers the bubble over other
  /// apps.
  Future<void> _minimize() async {
    final prefs = ref.read(prefsProvider);
    if (overlaySupported && !ref.read(overlayBubbleProvider) && !(prefs.getBool('overlay_offered') ?? false)) {
      await prefs.setBool('overlay_offered', true);
      if (mounted) await toggleOverlayBubble(context, ref);
    }
    if (mounted) context.go('/');
  }

  /// Pauses or resumes the workout.
  void _togglePause() {
    final notifier = ref.read(activeWorkoutProvider.notifier);
    if (ref.read(activeWorkoutProvider)?.paused ?? false) {
      notifier.resume();
    } else {
      setState(() => _holdStart = null);
      notifier.pause();
    }
  }

  /// Asks whether to minimize, pause, finish or discard the workout.
  Future<void> _exitDialog() async {
    final w = ref.read(activeWorkoutProvider);
    if (w == null) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.pause_circle_outline, size: 40),
        title: const Text('¿Qué quieres hacer?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            const Text(
              'Si pausas, el tiempo se detiene y puedes seguir luego desde la burbuja o la rutina.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.pop(c, 'continue'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Continuar'),
            ),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.pop(c, 'pause'),
              icon: const Icon(Icons.pause_rounded),
              label: const Text('Pausar'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: Theme.of(c).colorScheme.error,
                side: BorderSide(color: Theme.of(c).colorScheme.error),
              ),
              onPressed: () => Navigator.pop(c, 'abandon'),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Abandonar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    final notifier = ref.read(activeWorkoutProvider.notifier);
    switch (choice) {
      case 'pause':
        notifier.pause();
        context.go('/');
      case 'abandon':
        if (w.setsDone > 0) {
          final sure = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('¿Abandonar el entreno?'),
              content: Text('Se perderán las ${w.setsDone} series apuntadas y no contará para la racha.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Volver')),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Abandonar')),
              ],
            ),
          );
          if (sure != true || !mounted) return;
        }
        notifier.abandon();
        context.go('/');
    }
  }

  /// Finishes the workout, saves it and shows the celebration.
  Future<void> _finish() async {
    final w = ref.read(activeWorkoutProvider);
    if (w == null || _finishing) return;
    if (!w.allDone) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('¿Terminar ya?'),
          content: Text('Llevas ${w.setsDone} de ${w.setsTotal} series. Cuenta igual para la racha.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Seguir')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Terminar')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _finishing = true);
    final freezesBefore = ref.read(streakProvider).freezes;
    final log = await ref.read(activeWorkoutProvider.notifier).finish();
    final s = ref.read(streakProvider);
    if (!mounted || log == null) return;
    await showDialog<void>(
      context: context,
      builder: (c) => _CelebrationDialog(
        days: s.current(log.date),
        earnedFreeze: s.freezes > freezesBefore,
        duration: Duration(seconds: log.durationSeconds),
        sets: log.setsDone,
      ),
    );
    if (mounted) context.go('/');
  }

  /// Dialog to type a number (reps or kg) instead of using the buttons.
  Future<void> _editValue(
    String title,
    String initial,
    ValueChanged<String> onSave, {
    int maxLength = 5,
    bool decimal = true,
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]')),
            LengthLimitingTextInputFormatter(maxLength),
          ],
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

/// Formats [d] as "m:ss" or "h:mm:ss".
String mmss(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
}

/// Top bar: elapsed time and sets done.
class _StatsBar extends StatelessWidget {
  /// Creates the bar.
  const _StatsBar({
    required this.elapsed,
    required this.paused,
    required this.setsDone,
    required this.setsTotal,
  });

  /// Time trained.
  final Duration elapsed;

  /// Whether the workout is paused.
  final bool paused;

  /// Sets done.
  final int setsDone;

  /// Sets planned.
  final int setsTotal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget stat(IconData icon, String label, String value, Color color) => Expanded(
          child: Row(
            children: [
              IconTile(icon: icon, color: color, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: text.labelSmall?.copyWith(color: AppColors.muted, letterSpacing: 0.8)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            stat(
              paused ? Icons.pause : Icons.timer_outlined,
              paused ? 'EN PAUSA' : 'TIEMPO TOTAL',
              mmss(elapsed),
              paused ? AppColors.orange : AppColors.teal,
            ),
            stat(Icons.check_circle_outline, 'SERIES', '$setsDone/$setsTotal', AppColors.tealDark),
          ],
        ),
      ),
    );
  }
}

/// One circle per exercise to jump to any of them.
class _ExerciseDots extends StatelessWidget {
  /// Creates the dots.
  const _ExerciseDots({required this.workout, required this.onTap});

  /// The running workout.
  final ActiveWorkout workout;

  /// Jumps to an exercise index.
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 8,
        children: [
          for (var i = 0; i < workout.items.length; i++)
            Builder(builder: (context) {
              final done = workout.exerciseDone(i);
              final current = i == workout.exercise;
              return InkResponse(
                onTap: () => onTap(i),
                radius: 22,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? AppColors.teal : (current ? scheme.tertiary : scheme.surfaceContainerHighest),
                    border: current && done ? Border.all(color: scheme.tertiary, width: 3) : null,
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: current ? Colors.white : scheme.onSurface,
                          ),
                        ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Small icon + text badge.
class _Pill extends StatelessWidget {
  /// Creates the badge.
  const _Pill({required this.icon, required this.label, required this.color, this.strong = false});

  /// Leading icon.
  final IconData icon;

  /// Text.
  final String label;

  /// Tint color.
  final Color color;

  /// Filled background instead of a light tint.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: strong ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: strong ? Colors.white : color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: strong ? Colors.white : color),
          ),
        ],
      ),
    );
  }
}

/// The exercise animation, tappable to open its instructions.
class _MediaPanel extends StatelessWidget {
  /// Creates the panel.
  const _MediaPanel({required this.exercise});

  /// The exercise shown.
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 210,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExerciseMedia(exercise, animate: true),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton.filledTonal(
                tooltip: 'Cómo se hace',
                onPressed: () => context.push('/exercise/${exercise.id}'),
                icon: const Icon(Icons.info_outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full rest view: ring with the countdown and quick adjustments.
class _RestPanel extends StatelessWidget {
  /// Creates the panel.
  const _RestPanel({
    required this.left,
    required this.total,
    required this.next,
    required this.onShift,
    required this.onSkip,
    required this.onMinimize,
  });

  /// Seconds left.
  final int left;

  /// Rest length in seconds.
  final int total;

  /// What comes next.
  final String? next;

  /// Adds or removes seconds.
  final ValueChanged<int> onShift;

  /// Ends the rest now.
  final VoidCallback onSkip;

  /// Switches to the small bar.
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ending = left <= 5;
    final color = ending ? AppColors.orange : AppColors.teal;
    return Container(
      height: 210,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 176,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: total == 0 ? 0 : (left / total).clamp(0, 1).toDouble(),
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.18),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('DESCANSO', style: text.labelMedium?.copyWith(color: color, letterSpacing: 1.2)),
                      Text(
                        mmss(Duration(seconds: left)),
                        style: text.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: next == null
                          ? const SizedBox.shrink()
                          : Text('Siguiente: $next', style: text.bodyMedium, textAlign: TextAlign.center),
                    ),
                    IconButton(
                      tooltip: 'Minimizar el descanso y ver el ejercicio',
                      visualDensity: VisualDensity.compact,
                      onPressed: onMinimize,
                      icon: const Icon(Icons.close_fullscreen_rounded, size: 20),
                    ),
                  ],
                ),
                Row(
                  spacing: 6,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () => onShift(-15),
                        child: const Text('-15 s'),
                      ),
                    ),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () => onShift(15),
                        child: const Text('+15 s'),
                      ),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: onSkip,
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('Saltar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown while the workout is paused.
class _PausedPanel extends StatelessWidget {
  /// Creates the panel.
  const _PausedPanel({required this.onResume});

  /// Resumes the workout.
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          const Icon(Icons.pause_circle_filled, size: 72, color: AppColors.orange),
          Text('Entreno en pausa', style: text.titleLarge),
          Text('El tiempo y el descanso están parados.', style: text.bodyMedium),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

/// Stopwatch for timed sets: counts how long you hold.
class _HoldTimer extends StatelessWidget {
  /// Creates the timer.
  const _HoldTimer({
    required this.seconds,
    required this.target,
    required this.running,
    required this.onStart,
    required this.onStop,
  });

  /// Seconds held so far.
  final int seconds;

  /// Seconds to reach.
  final int target;

  /// Whether it is counting.
  final bool running;

  /// Starts counting (null = disabled).
  final VoidCallback? onStart;

  /// Stops and saves the time.
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reached = running && seconds >= target;
    final color = reached ? AppColors.orange : AppColors.teal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reached ? '¡Objetivo cumplido!' : 'Cronómetro de la serie',
                  style: text.labelLarge?.copyWith(color: color),
                ),
                Text(
                  '${mmss(Duration(seconds: running ? seconds : 0))} / ${mmss(Duration(seconds: target))}',
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          running
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: AppColors.navy),
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Parar'),
                )
              : FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Empezar'),
                ),
        ],
      ),
    );
  }
}

/// Big "Repeticiones  –  10  +", for sweaty fingers at the gym. Tapping the
/// number lets you type it.
class _BigStepper extends StatelessWidget {
  /// Creates the stepper.
  const _BigStepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.onEdit,
  });

  /// What it changes.
  final String label;

  /// Current value.
  final String value;

  /// Decreases it (null = at the minimum).
  final VoidCallback? onMinus;

  /// Increases it (null = at the maximum).
  final VoidCallback? onPlus;

  /// Opens the typing dialog.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(label, style: text.labelLarge?.copyWith(color: AppColors.muted)),
          const SizedBox(height: 4),
          Row(
            children: [
              _RoundButton(icon: Icons.remove, onTap: onMinus),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onEdit,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: text.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
              _RoundButton(icon: Icons.add, onTap: onPlus),
            ],
          ),
        ],
      ),
    );
  }
}

/// Round − / + button of the stepper.
class _RoundButton extends StatelessWidget {
  /// Creates the button.
  const _RoundButton({required this.icon, required this.onTap});

  /// Icon.
  final IconData icon;

  /// Action (null = disabled).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 40,
          child: Icon(icon, size: 22, color: onTap == null ? scheme.outline : scheme.onSurface),
        ),
      ),
    );
  }
}

/// One set of the exercise: number, values and whether it is done.
class _SetChip extends StatelessWidget {
  /// Creates the chip.
  const _SetChip({
    required this.index,
    required this.text,
    required this.done,
    required this.selected,
    required this.onTap,
  });

  /// Set index.
  final int index;

  /// "10 × 20 kg".
  final String text;

  /// Whether it is logged.
  final bool done;

  /// Whether it is the one shown.
  final bool selected;

  /// Selects it to correct it.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelLarge;
    return Material(
      color: done ? AppColors.teal.withValues(alpha: 0.14) : scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: selected ? BorderSide(color: scheme.tertiary, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: done ? AppColors.teal : scheme.surface,
                child: done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text('${index + 1}', style: const TextStyle(fontSize: 11)),
              ),
              Text(text, style: style),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the exercise (or the whole workout) is done.
class _DoneCard extends StatelessWidget {
  /// Creates the card.
  const _DoneCard({required this.allDone});

  /// Whether every exercise is done.
  final bool allDone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.teal, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              allDone ? '¡Todo hecho! Termina el entreno para sumar a la racha.' : 'Ejercicio completado.',
              style: text.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimized rest: a countdown bar above the exercise animation.
class _RestBar extends StatelessWidget {
  /// Creates the bar.
  const _RestBar({
    required this.left,
    required this.total,
    required this.onShift,
    required this.onSkip,
    required this.onExpand,
  });

  /// Seconds left.
  final int left;

  /// Rest length in seconds.
  final int total;

  /// Adds or removes seconds.
  final ValueChanged<int> onShift;

  /// Ends the rest now.
  final VoidCallback onSkip;

  /// Back to the full rest view.
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = left <= 5 ? AppColors.orange : AppColors.teal;
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onExpand,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: color),
                  const SizedBox(width: 8),
                  Text(
                    mmss(Duration(seconds: left)),
                    style: text.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: () => onShift(-15), child: const Text('-15')),
                  TextButton(onPressed: () => onShift(15), child: const Text('+15')),
                  IconButton(
                    tooltip: 'Saltar descanso',
                    visualDensity: VisualDensity.compact,
                    onPressed: onSkip,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                  IconButton(
                    tooltip: 'Agrandar',
                    visualDensity: VisualDensity.compact,
                    onPressed: onExpand,
                    icon: const Icon(Icons.open_in_full_rounded, size: 20),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: total == 0 ? 0 : (left / total).clamp(0, 1).toDouble(),
              minHeight: 4,
              color: color,
              backgroundColor: color.withValues(alpha: 0.18),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tip line under the sets, with an optional action button.
class _Hint extends StatelessWidget {
  /// Creates the tip.
  const _Hint(this.text, {this.actionLabel, this.onAction});

  /// Tip text.
  final String text;

  /// Button text.
  final String? actionLabel;

  /// Button action.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, size: 18, color: AppColors.orange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: readableOn(context, AppColors.orange)),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: readableOn(context, AppColors.orange), visualDensity: VisualDensity.compact),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// End-of-workout dialog: streak, time, sets and any freeze earned.
class _CelebrationDialog extends StatelessWidget {
  /// Creates the dialog.
  const _CelebrationDialog({
    required this.days,
    required this.earnedFreeze,
    required this.duration,
    required this.sets,
  });

  /// Streak days.
  final int days;

  /// Whether a freeze was earned.
  final bool earnedFreeze;

  /// Workout length.
  final Duration duration;

  /// Sets done.
  final int sets;

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
          Text(
            '¡Entreno completado!\n$sets series en ${mmss(duration)}',
            textAlign: TextAlign.center,
          ),
          if (earnedFreeze) ...[
            const SizedBox(height: 12),
            const Text('🧊 Has ganado un protector de racha', textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          const SizedBox(width: 300, child: QuoteCard(height: 170)),
        ],
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Genial')),
      ],
    );
  }
}
