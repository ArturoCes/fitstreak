import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/exercise.dart';
import '../../data/exercise_repository.dart';
import '../../data/labels_es.dart';
import '../../data/progress_state.dart';
import '../../data/routine.dart';

class RoutineScreen extends ConsumerWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routine = ref.watch(routineProvider);
    final profile = ref.watch(profileProvider);
    final exercises = ref.watch(exercisesProvider);

    if (routine == null || profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final nextDay = ref.watch(nextDayIndexProvider);
    final streak = ref.watch(streakProvider);

    return DefaultTabController(
      // Al terminar un entreno cambia el día que toca: recrear para saltar a él.
      key: ValueKey((routine.days.length, nextDay)),
      length: routine.days.length,
      initialIndex: nextDay,
      child: Scaffold(
        floatingActionButton: Builder(
          builder: (context) {
            final tabs = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabs,
              builder: (_, _) => FloatingActionButton.extended(
                onPressed: () => context.push('/workout/${tabs.index}'),
                icon: const Icon(Icons.play_arrow),
                label: Text(tabs.index == nextDay ? 'Empezar (toca hoy)' : 'Empezar'),
              ),
            );
          },
        ),
        appBar: AppBar(
          title: const Text('Mi rutina'),
          actions: [
            Chip(
              avatar: const Text('🔥'),
              label: Text('${streak.current(DateTime.now())}'),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'regen') {
                  await ref.read(routineProvider.notifier).regenerate();
                } else if (v == 'profile' && context.mounted) {
                  context.go('/onboarding');
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'regen', child: Text('Generar otra rutina')),
                PopupMenuItem(value: 'profile', child: Text('Cambiar mis datos')),
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final d in routine.days) Tab(text: d.name)],
          ),
        ),
        body: exercises.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (all) {
            final byId = {for (final e in all) e.id: e};
            return TabBarView(
              children: [
                for (final (d, day) in routine.days.indexed)
                  ListView(
                    // Hueco abajo para que el botón de empezar no tape nada.
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                        child: Text(
                          '${profile.goal.label} · ${profile.level.label} · '
                          '${profile.minutesPerSession} min · ${profile.place.label}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      for (final (i, item) in day.items.indexed)
                        if (byId[item.exerciseId] case final ex?)
                          _ItemCard(day: d, index: i, item: item, exercise: ex),
                    ],
                  ),
              ],
            );
          },
        ),
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
    final urls = exercise.imageUrls;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/exercise/${exercise.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: 64,
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
                    Text(item.slot, style: text.labelSmall),
                    Text(exercise.name, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${item.sets} × ${item.reps} · descanso ${item.restSeconds} s',
                      style: text.bodyMedium,
                    ),
                    Text(
                      es(equipmentEs, exercise.equipmentOrBody),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cambiar ejercicio',
                icon: const Icon(Icons.swap_horiz),
                onPressed: () => _showAlternatives(context, ref),
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
              leading: const Icon(Icons.block),
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
