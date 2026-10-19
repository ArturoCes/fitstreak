import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'exercise.dart';

/// Carga el catálogo empaquetado en assets. Más adelante vendrá de Supabase
/// con esta copia como caché offline.
final exercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/exercises.json');
  final list = jsonDecode(raw) as List<dynamic>;
  return [for (final e in list) Exercise.fromJson(e as Map<String, dynamic>)]
    ..sort((a, b) => a.name.compareTo(b.name));
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
