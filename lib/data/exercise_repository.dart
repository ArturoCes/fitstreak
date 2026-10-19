import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import 'exercise.dart';

/// Carga el catálogo empaquetado en assets. Más adelante vendrá de Supabase
/// con esta copia como caché offline.
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
  ]..sort((a, b) => a.name.compareTo(b.name));
});

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

/// true = dibujos (cuando existan), false = fotos.
class PreferDrawingsNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsProvider).getBool(_drawingsKey) ?? false;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(prefsProvider).setBool(_drawingsKey, value);
  }
}

final preferDrawingsProvider = NotifierProvider<PreferDrawingsNotifier, bool>(
  PreferDrawingsNotifier.new,
);
