import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exercise.dart';
import '../../data/exercise_repository.dart';

/// Search text and filters of the exercise catalog.
class CatalogFilter {
  /// Creates a filter (empty by default).
  const CatalogFilter({
    this.query = '',
    this.muscle,
    this.equipment,
    this.level,
  });

  /// Lower-case text the name must contain.
  final String query;

  /// Primary muscle key (null = any).
  final String? muscle;

  /// Equipment key (null = any).
  final String? equipment;

  /// Level key (null = any).
  final String? level;

  /// Whether no filter is set.
  bool get isEmpty =>
      query.isEmpty && muscle == null && equipment == null && level == null;

  /// Whether [e] passes every filter.
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

/// The catalog's current filter.
class CatalogFilterNotifier extends Notifier<CatalogFilter> {
  /// Starts with no filter.
  @override
  CatalogFilter build() => const CatalogFilter();

  /// Sets the search text.
  void setQuery(String q) => state = CatalogFilter(
        query: q.trim().toLowerCase(),
        muscle: state.muscle,
        equipment: state.equipment,
        level: state.level,
      );

  /// Sets the muscle filter (null clears it).
  void setMuscle(String? v) => state = CatalogFilter(
        query: state.query,
        muscle: v,
        equipment: state.equipment,
        level: state.level,
      );

  /// Sets the equipment filter (null clears it).
  void setEquipment(String? v) => state = CatalogFilter(
        query: state.query,
        muscle: state.muscle,
        equipment: v,
        level: state.level,
      );

  /// Sets the level filter (null clears it).
  void setLevel(String? v) => state = CatalogFilter(
        query: state.query,
        muscle: state.muscle,
        equipment: state.equipment,
        level: v,
      );

  /// Removes every filter.
  void clear() => state = const CatalogFilter();
}

/// The catalog's current filter.
final catalogFilterProvider =
    NotifierProvider<CatalogFilterNotifier, CatalogFilter>(
  CatalogFilterNotifier.new,
);

/// Catalog exercises that pass the filter (with drawings first in drawing
/// mode).
final filteredExercisesProvider = Provider<AsyncValue<List<Exercise>>>((ref) {
  final filter = ref.watch(catalogFilterProvider);
  final drawingsFirst = ref.watch(preferDrawingsProvider);
  return ref.watch(exercisesProvider).whenData((all) {
    final list = all.where(filter.matches).toList();
    // In drawing mode, the ones that have one go first (alphabetical order is
    // kept within each group).
    return drawingsFirst
        ? [...list.where((e) => e.drawings.isNotEmpty), ...list.where((e) => e.drawings.isEmpty)]
        : list;
  });
});
