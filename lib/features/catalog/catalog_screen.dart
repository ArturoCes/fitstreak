import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/exercise.dart';
import '../../data/labels_es.dart';
import '../../ui/exercise_media.dart';
import '../../ui/theme.dart';
import 'catalog_filter.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(catalogFilterProvider);
    final notifier = ref.read(catalogFilterProvider.notifier);
    final results = ref.watch(filteredExercisesProvider);
    final text = Theme.of(context).textTheme;
    final extraFilters = (filter.equipment != null ? 1 : 0) + (filter.level != null ? 1 : 0);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList.list(
                children: [
                  Text('Encuentra tu\nejercicio', style: text.headlineMedium),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: notifier.setQuery,
                          decoration: const InputDecoration(
                            hintText: 'Buscar',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Badge(
                        isLabelVisible: extraFilters > 0,
                        label: Text('$extraFilters'),
                        child: IconTile(
                          icon: Icons.tune,
                          size: 52,
                          tooltip: 'Filtros',
                          onTap: () => _showFilters(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Músculos', style: text.titleMedium),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  spacing: 8,
                  children: [
                    _MuscleChip(
                      label: 'Todos',
                      selected: filter.muscle == null,
                      onTap: () => notifier.setMuscle(null),
                    ),
                    for (final MapEntry(:key, :value) in muscleEs.entries)
                      _MuscleChip(
                        label: value,
                        selected: filter.muscle == key,
                        onTap: () => notifier.setMuscle(filter.muscle == key ? null : key),
                      ),
                  ],
                ),
              ),
            ),
            ...results.when(
              loading: () => [
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
              ],
              error: (e, _) => [
                SliverFillRemaining(child: Center(child: Text('Error cargando datos: $e'))),
              ],
              data: (list) => [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(child: Text('${list.length} ejercicios', style: text.bodySmall)),
                        const MediaStyleToggle(),
                      ],
                    ),
                  ),
                ),
                if (list.isEmpty)
                  const SliverFillRemaining(child: Center(child: Text('Sin resultados')))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _ExerciseCard(list[i]),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilters(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => const _FiltersSheet(),
      );
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface),
      onSelected: (_) => onTap(),
    );
  }
}

class _FiltersSheet extends ConsumerWidget {
  const _FiltersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(catalogFilterProvider);
    final notifier = ref.read(catalogFilterProvider.notifier);
    final text = Theme.of(context).textTheme;

    Widget group(String title, Map<String, String> options, String? value,
            ValueChanged<String?> onChanged) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(:key, value: name) in options.entries)
                  _MuscleChip(
                    label: name,
                    selected: value == key,
                    onTap: () => onChanged(value == key ? null : key),
                  ),
              ],
            ),
          ],
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Filtros', style: text.titleLarge),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    notifier.setEquipment(null);
                    notifier.setLevel(null);
                  },
                  child: const Text('Limpiar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            group('Equipo', equipmentEs, filter.equipment, notifier.setEquipment),
            const SizedBox(height: 20),
            group('Nivel', levelEs, filter.level, notifier.setLevel),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ver resultados'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard(this.exercise);

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/exercise/${exercise.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ExerciseMedia(exercise),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${es(muscleEs, exercise.primaryMuscles.firstOrNull)} · '
                    '${es(equipmentEs, exercise.equipmentOrBody)}',
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
