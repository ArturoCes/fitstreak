import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exercise.dart';
import '../../data/exercise_repository.dart';
import '../../data/labels_es.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseByIdProvider(id));
    return Scaffold(
      appBar: AppBar(),
      body: exercise.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (e) => e == null
            ? const Center(child: Text('Ejercicio no encontrado'))
            : _Detail(e),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.e);

  final Exercise e;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(e.name, style: text.headlineSmall),
        const SizedBox(height: 12),
        if (e.imageUrls.isNotEmpty)
          SizedBox(
            height: 220,
            child: PageView(
              children: [
                for (final url in e.imageUrls)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in e.primaryMuscles)
              Chip(label: Text(es(muscleEs, m))),
            Chip(label: Text(es(equipmentEs, e.equipmentOrBody))),
            Chip(label: Text(es(levelEs, e.level))),
            Chip(label: Text(es(categoryEs, e.category))),
            if (e.mechanic != null) Chip(label: Text(es(mechanicEs, e.mechanic))),
          ],
        ),
        if (e.secondaryMuscles.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Secundarios: ${e.secondaryMuscles.map((m) => es(muscleEs, m)).join(', ')}',
          ),
        ],
        const SizedBox(height: 16),
        Text('Instrucciones', style: text.titleMedium),
        const SizedBox(height: 8),
        for (final (i, step) in e.instructions.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 12, child: Text('${i + 1}')),
                const SizedBox(width: 8),
                Expanded(child: Text(step)),
              ],
            ),
          ),
      ],
    );
  }
}
