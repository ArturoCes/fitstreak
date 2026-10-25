import 'dart:convert';
import 'dart:math';

import 'package:fitstreak/data/app_state.dart';
import 'package:fitstreak/data/exercise_repository.dart';
import 'package:fitstreak/data/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const profile = UserProfile(
    age: 25,
    heightCm: 175,
    weightKg: 75,
    goal: Goal.muscle,
    level: Level.intermediate,
    daysPerWeek: 4,
    minutesPerSession: 60,
    place: Place.gym,
    equipment: {...datasetEquipment, ...extraEquipment},
    injuries: {},
  );

  Future<ProviderContainer> container() async {
    SharedPreferences.setMockInitialValues({'profile': jsonEncode(profile.toJson())});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    await c.read(routineProvider.notifier).regenerate();
    return c;
  }

  test('cambia los ejercicios de un día por otros de los mismos músculos', () async {
    final c = await container();
    final before = c.read(routineProvider)!;
    final old = before.days[1].items;

    final undo = await c.read(routineProvider.notifier).regenerateDay(1, random: Random(1));
    final after = c.read(routineProvider)!;
    final fresh = after.days[1].items;

    expect(undo, same(before));
    expect(fresh, hasLength(old.length));
    // Ninguno repetido dentro del día y todos distintos de los de antes.
    expect({for (final i in fresh) i.exerciseId}, hasLength(fresh.length));
    expect(fresh.where((i) => old.any((o) => o.exerciseId == i.exerciseId)), isEmpty);
    // Mismas series y descansos, y los demás días intactos.
    for (final (n, i) in fresh.indexed) {
      expect((i.sets, i.reps, i.restSeconds), (old[n].sets, old[n].reps, old[n].restSeconds));
    }
    expect(after.days[0].items.map((i) => i.exerciseId), before.days[0].items.map((i) => i.exerciseId));

    // Trabajan lo mismo: comparten al menos un músculo principal.
    final byId = {for (final e in await c.read(exercisesProvider.future)) e.id: e};
    for (final (n, i) in fresh.indexed) {
      final a = byId[old[n].exerciseId]!.primaryMuscles;
      final b = byId[i.exerciseId]!.primaryMuscles;
      expect(a.any(b.contains), isTrue, reason: '${old[n].exerciseId} → ${i.exerciseId}');
    }
  });

  test('deshacer deja la rutina como estaba', () async {
    final c = await container();
    final notifier = c.read(routineProvider.notifier);
    final before = await notifier.regenerateDay(0);
    await notifier.replaceWith(before!);
    expect(c.read(routineProvider), same(before));
  });
}
