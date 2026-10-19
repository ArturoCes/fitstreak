import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exercise.dart';
import '../../data/exercise_repository.dart';
import '../../data/labels_es.dart';
import '../../ui/exercise_media.dart';
import '../../ui/theme.dart';

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

class _Detail extends ConsumerWidget {
  const _Detail(this.e);

  final Exercise e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final showingDrawings = ref.watch(preferDrawingsProvider) && e.drawings.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExerciseMedia(e, animate: true, fit: BoxFit.contain),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const MediaStyleToggle(),
            const Spacer(),
            if (ref.watch(preferDrawingsProvider) && e.drawings.isEmpty)
              Flexible(
                child: Text('Sin dibujo para este', style: text.bodySmall, textAlign: TextAlign.end),
              ),
          ],
        ),
        if (showingDrawings)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Dibujo: Everkinetic · CC BY-SA 4.0', style: text.bodySmall),
          ),
        const SizedBox(height: 16),
        Text(e.name, style: text.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in e.primaryMuscles) _Tag(es(muscleEs, m), AppColors.teal),
            _Tag(es(equipmentEs, e.equipmentOrBody), AppColors.orange),
            _Tag(es(levelEs, e.level), Theme.of(context).colorScheme.tertiary),
            if (e.mechanic != null) _Tag(es(mechanicEs, e.mechanic), Theme.of(context).colorScheme.tertiary),
          ],
        ),
        if (e.secondaryMuscles.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Secundarios: ${e.secondaryMuscles.map((m) => es(muscleEs, m)).join(', ')}',
            style: text.bodySmall,
          ),
        ],
        const SizedBox(height: 24),
        Text('Cómo hacerlo', style: text.titleLarge),
        const SizedBox(height: 12),
        for (final (i, step) in e.steps.indexed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.teal,
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(step)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}
