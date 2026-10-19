import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/exercise.dart';
import '../../data/labels_es.dart';
import 'catalog_filter.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(catalogFilterProvider);
    final notifier = ref.read(catalogFilterProvider.notifier);
    final results = ref.watch(filteredExercisesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ejercicios')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              hintText: 'Buscar ejercicio',
              leading: const Icon(Icons.search),
              onChanged: notifier.setQuery,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              spacing: 8,
              children: [
                _FilterChip(
                  label: 'Músculo',
                  value: filter.muscle,
                  options: muscleEs,
                  onSelected: notifier.setMuscle,
                ),
                _FilterChip(
                  label: 'Equipo',
                  value: filter.equipment,
                  options: equipmentEs,
                  onSelected: notifier.setEquipment,
                ),
                _FilterChip(
                  label: 'Nivel',
                  value: filter.level,
                  options: levelEs,
                  onSelected: notifier.setLevel,
                ),
                if (!filter.isEmpty)
                  TextButton(
                    onPressed: notifier.clear,
                    child: const Text('Limpiar'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error cargando datos: $e')),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('Sin resultados'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => _ExerciseTile(list[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(value == null ? label : es(options, value)),
      selected: value != null,
      onSelected: (_) async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (sheet) => ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Todos'),
                onTap: () => Navigator.pop(sheet, ''),
              ),
              for (final MapEntry(:key, value: name) in options.entries)
                ListTile(
                  title: Text(name),
                  selected: key == value,
                  onTap: () => Navigator.pop(sheet, key),
                ),
            ],
          ),
        );
        if (picked == null) return; // cerrado sin elegir
        onSelected(picked.isEmpty ? null : picked);
      },
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile(this.exercise);

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final urls = exercise.imageUrls;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 56,
          child: urls.isEmpty
              ? const Icon(Icons.fitness_center)
              : CachedNetworkImage(
                  imageUrl: urls.first,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const Icon(Icons.fitness_center),
                ),
        ),
      ),
      title: Text(exercise.name),
      subtitle: Text(
        '${exercise.primaryMuscles.map((m) => es(muscleEs, m)).join(', ')}'
        ' · ${es(equipmentEs, exercise.equipmentOrBody)}',
      ),
      onTap: () => context.push('/exercise/${exercise.id}'),
    );
  }
}
