import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'exercise.dart';

/// The full catalog: the dataset bundled in assets (with drawings and
/// Spanish instructions) plus the user's own exercises, sorted by name.
final exercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/exercises.json');
  final drawingsRaw = await rootBundle.loadString('assets/data/drawings.json');
  final drawings = (jsonDecode(drawingsRaw) as Map<String, dynamic>)
      .map((id, v) => MapEntry(id, (v as List).cast<String>()));
  final esRaw = await rootBundle.loadString('assets/data/instructions_es.json');
  final instructionsEs = (jsonDecode(esRaw) as Map<String, dynamic>)
      .map((id, v) => MapEntry(id, (v as List).cast<String>()));
  final list = jsonDecode(raw) as List<dynamic>;
  return [
    for (final e in list)
      Exercise.fromJson(
        e as Map<String, dynamic>,
        drawings: drawings[e['id']] ?? const [],
        instructionsEs: instructionsEs[e['id']] ?? const [],
      ),
    ...loadCustomExercises(ref.read(prefsProvider)),
  ]..sort((a, b) => a.name.compareTo(b.name));
});

const _customKey = 'custom_exercises';

/// Id prefix of the user's own exercises.
const customPrefix = 'custom-';

/// Whether [id] belongs to one of the user's own exercises.
bool isCustomExercise(String id) => id.startsWith(customPrefix);

/// An exercise from an imported routine that is not in the catalog: no
/// photos or instructions, just the name the user wrote.
Exercise customExercise({required String id, required String name, required String equipment}) => Exercise(
      id: id,
      name: name,
      level: 'beginner',
      category: 'strength',
      primaryMuscles: const [],
      secondaryMuscles: const [],
      instructions: const [],
      images: const [],
      equipment: equipment,
    );

/// The user's own exercises saved in [prefs].
List<Exercise> loadCustomExercises(SharedPreferences prefs) {
  final raw = prefs.getString(_customKey);
  if (raw == null) return const [];
  return [
    for (final c in jsonDecode(raw) as List)
      customExercise(
        id: c['id'] as String,
        name: c['name'] as String,
        equipment: c['equipment'] as String,
      ),
  ];
}

/// Adds own exercises (ones with an existing id are replaced). Invalidate
/// [exercisesProvider] afterwards to see them in the catalog.
Future<void> saveCustomExercises(SharedPreferences prefs, List<Exercise> added) async {
  final byId = {for (final e in loadCustomExercises(prefs)) e.id: e, for (final e in added) e.id: e};
  await prefs.setString(_customKey, jsonEncode([
    for (final e in byId.values) {'id': e.id, 'name': e.name, 'equipment': e.equipment},
  ]));
}

/// One exercise by id (null if it doesn't exist).
final exerciseByIdProvider = FutureProvider.family<Exercise?, String>((
  ref,
  id,
) async {
  final all = await ref.watch(exercisesProvider.future);
  for (final e in all) {
    if (e.id == id) return e;
  }
  return null;
});

const _drawingsKey = 'prefer_drawings';

/// Photos or drawings preference: true = drawings (when available), false =
/// photos.
class PreferDrawingsNotifier extends Notifier<bool> {
  /// Loads the saved preference (photos by default).
  @override
  bool build() => ref.read(prefsProvider).getBool(_drawingsKey) ?? false;

  /// Applies and saves [value].
  Future<void> set(bool value) async {
    state = value;
    await ref.read(prefsProvider).setBool(_drawingsKey, value);
  }
}

/// Whether to show drawings instead of photos.
final preferDrawingsProvider = NotifierProvider<PreferDrawingsNotifier, bool>(
  PreferDrawingsNotifier.new,
);
