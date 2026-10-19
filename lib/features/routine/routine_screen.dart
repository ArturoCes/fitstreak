import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/exercise.dart';
import '../../data/exercise_repository.dart';
import '../../data/labels_es.dart';
import '../../data/progress_state.dart';
import '../../data/routine.dart';
import '../../data/settings_state.dart';
import '../../ui/exercise_media.dart';
import '../../ui/theme.dart';

class RoutineScreen extends ConsumerStatefulWidget {
  const RoutineScreen({super.key});

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  /// Día elegido a mano; null = el que toca.
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final routine = ref.watch(routineProvider);
    final profile = ref.watch(profileProvider);
    final exercises = ref.watch(exercisesProvider).value;
    final nextDay = ref.watch(nextDayIndexProvider);
    final streak = ref.watch(streakProvider);
    // Tras un entreno cambia el día que toca: volvemos a él.
    ref.listen(nextDayIndexProvider, (_, _) => setState(() => _picked = null));

    if (routine == null || profile == null || exercises == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final byId = {for (final e in exercises) e.id: e};
    final selected = (_picked ?? nextDay).clamp(0, routine.days.length - 1);
    final day = routine.days[selected];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                IconTile(
                  icon: Icons.tune,
                  color: Theme.of(context).colorScheme.tertiary,
                  tooltip: 'Opciones',
                  onTap: () => _showOptions(context),
                ),
                const Spacer(),
                StreakPill(streak.current(DateTime.now())),
              ],
            ),
            const SizedBox(height: 20),
            Text('Hola 👋', style: text.titleMedium?.copyWith(color: AppColors.muted)),
            Text(
              selected == nextDay ? '¡Vamos a por\nel entreno de hoy!' : 'Echa un vistazo\na otro día',
              style: text.headlineMedium,
            ),
            const SizedBox(height: 20),
            _HeroCard(
              day: day,
              isToday: selected == nextDay,
              minutes: profile.minutesPerSession,
              preview: day.items.isEmpty ? null : byId[day.items.first.exerciseId],
              onStart: () => context.push('/workout/$selected'),
            ),
            const SizedBox(height: 24),
            Text('Tus días', style: text.titleMedium),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8,
                children: [
                  for (final (i, d) in routine.days.indexed)
                    ChoiceChip(
                      label: Text(i == nextDay ? '${d.name} · hoy' : d.name),
                      selected: i == selected,
                      showCheckmark: false,
                      labelStyle: text.bodyMedium?.copyWith(
                        color: i == selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      ),
                      onSelected: (_) => setState(() => _picked = i),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('Ejercicios', style: text.titleMedium),
                const Spacer(),
                Text(
                  '${profile.goal.label} · ${profile.place.label}',
                  style: text.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final (i, item) in day.items.indexed)
              if (byId[item.exerciseId] case final ex?)
                _ItemCard(day: selected, index: i, item: item, exercise: ex),
          ],
        ),
      ),
    );
  }

  Future<void> _showOptions(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const IconTile(icon: Icons.refresh, color: AppColors.teal, size: 36),
              title: const Text('Generar otra rutina'),
              onTap: () => Navigator.pop(sheet, 'regen'),
            ),
            ListTile(
              leading: const IconTile(icon: Icons.person_outline, color: AppColors.orange, size: 36),
              title: const Text('Cambiar mis datos'),
              onTap: () => Navigator.pop(sheet, 'profile'),
            ),
            ListTile(
              leading: const IconTile(icon: Icons.dark_mode_outlined, color: AppColors.tealDark, size: 36),
              title: const Text('Tema'),
              subtitle: Text(_themeLabel(ref.read(themeModeProvider))),
              onTap: () => Navigator.pop(sheet, 'theme'),
            ),
            ListTile(
              leading: IconTile(icon: Icons.info_outline, color: Theme.of(sheet).colorScheme.tertiary, size: 36),
              title: const Text('Créditos de imágenes'),
              onTap: () => Navigator.pop(sheet, 'credits'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'regen':
        await ref.read(routineProvider.notifier).regenerate();
      case 'profile':
        context.go('/onboarding');
      case 'theme':
        final picked = await showDialog<ThemeMode>(
          context: context,
          builder: (c) => SimpleDialog(
            title: const Text('Tema'),
            children: [
              for (final m in ThemeMode.values)
                ListTile(
                  title: Text(_themeLabel(m)),
                  trailing: m == ref.read(themeModeProvider) ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(c, m),
                ),
            ],
          ),
        );
        if (picked != null) await ref.read(themeModeProvider.notifier).set(picked);
      case 'credits':
        showDialog<void>(context: context, builder: (_) => const _CreditsDialog());
    }
  }

  static String _themeLabel(ThemeMode m) => switch (m) {
        ThemeMode.system => 'Como el sistema',
        ThemeMode.light => 'Claro',
        ThemeMode.dark => 'Oscuro',
      };
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.day,
    required this.isToday,
    required this.minutes,
    required this.preview,
    required this.onStart,
  });

  final RoutineDay day;
  final bool isToday;
  final int minutes;
  final Exercise? preview;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.teal, AppColors.tealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'HOY TOCA' : 'DÍA',
                  style: text.labelMedium?.copyWith(color: Colors.white70, letterSpacing: 1.2),
                ),
                const SizedBox(height: 4),
                Text(day.name, style: text.titleLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  '${day.items.length} ejercicios · $minutes min',
                  style: text.bodyMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Empezar'),
                ),
              ],
            ),
          ),
          if (preview != null) ...[
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 110,
                height: 120,
                child: ExerciseMedia(preview!, animate: true),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  const _ItemCard({
    required this.day,
    required this.index,
    required this.item,
    required this.exercise,
  });

  final int day;
  final int index;
  final RoutineItem item;
  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/exercise/${exercise.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox.square(dimension: 72, child: ExerciseMedia(exercise)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.slot.toUpperCase(),
                      style: text.labelSmall?.copyWith(color: AppColors.teal, letterSpacing: 0.8),
                    ),
                    Text(exercise.name, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(
                      '${item.sets} × ${item.reps} · ${item.restSeconds} s · '
                      '${es(equipmentEs, exercise.equipmentOrBody)}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconTile(
                icon: Icons.swap_horiz,
                size: 36,
                tooltip: 'Cambiar ejercicio',
                onTap: () => _showAlternatives(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAlternatives(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(routineProvider.notifier);
    final gen = await notifier.generator();
    final options = gen.alternatives(exercise);
    if (!context.mounted) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scroll) => ListView(
          controller: scroll,
          children: [
            ListTile(
              leading: IconTile(icon: Icons.block, color: Theme.of(sheet).colorScheme.tertiary, size: 36),
              title: const Text('No tengo este equipo o máquina'),
              subtitle: const Text('No volveremos a proponértelo'),
              onTap: () => Navigator.pop(sheet, '__block__'),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                options.isEmpty
                    ? 'No hay alternativas con tu equipo'
                    : 'Alternativas que trabajan lo mismo',
                style: Theme.of(sheet).textTheme.titleSmall,
              ),
            ),
            for (final alt in options)
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.square(dimension: 48, child: ExerciseMedia(alt)),
                ),
                title: Text(alt.name),
                subtitle: Text(
                  '${es(equipmentEs, alt.equipmentOrBody)} · ${es(levelEs, alt.level)}',
                ),
                onTap: () => Navigator.pop(sheet, alt.id),
              ),
          ],
        ),
      ),
    );

    if (picked == null) return;
    if (picked == '__block__') {
      await notifier.block(day, index);
    } else {
      await notifier.swap(day, index, picked);
    }
  }
}

class _CreditsDialog extends StatelessWidget {
  const _CreditsDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créditos'),
      content: const Text(
        'Fotos e instrucciones: free-exercise-db (github.com/yuhonas/free-exercise-db), '
        'dominio público.\n\n'
        'Dibujos: Everkinetic (github.com/everkinetic/data), licencia '
        'Creative Commons BY-SA 4.0.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}
