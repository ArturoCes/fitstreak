import 'dart:convert';
import 'dart:io';

import 'package:fitstreak/data/exercise.dart';
import 'package:fitstreak/features/catalog/catalog_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final all = [
    for (final e
        in jsonDecode(File('assets/data/exercises.json').readAsStringSync())
            as List<dynamic>)
      Exercise.fromJson(e as Map<String, dynamic>),
  ];

  test('carga todo el dataset', () {
    expect(all.length, greaterThan(800));
    // Unos pocos (3 kettlebell) vienen sin imagen; la UI pone un icono.
    expect(all.where((e) => e.images.isEmpty).length, lessThan(10));
  });

  test('filtra por músculo y equipo', () {
    const f = CatalogFilter(muscle: 'chest', equipment: 'dumbbell');
    final r = all.where(f.matches).toList();
    expect(r, isNotEmpty);
    expect(
      r.every((e) => e.primaryMuscles.contains('chest') && e.equipment == 'dumbbell'),
      isTrue,
    );
  });

  test('sin equipo especificado cuenta como peso corporal', () {
    const f = CatalogFilter(equipment: 'body only');
    final r = all.where(f.matches);
    expect(r.any((e) => e.equipment == null), isTrue);
  });

  test('búsqueda por nombre', () {
    const f = CatalogFilter(query: 'push-up');
    expect(all.where(f.matches), isNotEmpty);
  });

  test('buscar un músculo en español da lo mismo que el filtro', () {
    final byText = all.where(const CatalogFilter(query: 'abdominales').matches).toSet();
    final byChip = all.where(const CatalogFilter(muscle: 'abdominals').matches).toSet();
    expect(byText.containsAll(byChip), isTrue);
    // Sin tilde también vale, y se combinan palabras.
    expect(all.where(const CatalogFilter(query: 'biceps mancuernas').matches), isNotEmpty);
  });
}
