import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exercise.dart';
import '../../data/exercise_repository.dart';

class CatalogFilter {
  const CatalogFilter({
    this.query = '',
    this.muscle,
    this.equipment,
    this.level,
  });

  final String query;
  final String? muscle;
  final String? equipment;
  final String? level;

  bool get isEmpty =>
      query.isEmpty && muscle == null && equipment == null && level == null;

  bool matches(Exercise e) {
    if (muscle != null && !e.primaryMuscles.contains(muscle)) return false;
    if (equipment != null && e.equipmentOrBody != equipment) return false;
    if (level != null && e.level != level) return false;
    if (query.isNotEmpty && !e.name.toLowerCase().contains(query)) {
      return false;
    }
    return true;
  }
}

class CatalogFilterNotifier extends Notifier<CatalogFilter> {
  @override
  CatalogFilter build() => const CatalogFilter();

  void setQuery(String q) => state = CatalogFilter(
        query: q.trim().toLowerCase(),
        muscle: state.muscle,
        equipment: state.equipment,
        level: state.level,
      );

  void setMuscle(String? v) => state = CatalogFilter(
        query: state.query,
        muscle: v,
        equipment: state.equipment,
        level: state.level,
      );

  void setEquipment(String? v) => state = CatalogFilter(
        query: state.query,
        muscle: state.muscle,
        equipment: v,
        level: state.level,
      );

  void setLevel(String? v) => state = CatalogFilter(
        query: state.query,
        muscle: state.muscle,
        equipment: state.equipment,
        level: v,
      );

  void clear() => state = const CatalogFilter();
}

final catalogFilterProvider =
    NotifierProvider<CatalogFilterNotifier, CatalogFilter>(
  CatalogFilterNotifier.new,
);

final filteredExercisesProvider = Provider<AsyncValue<List<Exercise>>>((ref) {
  final filter = ref.watch(catalogFilterProvider);
  return ref
      .watch(exercisesProvider)
      .whenData((all) => all.where(filter.matches).toList());
});
