import 'package:fitstreak/data/app_state.dart';
import 'package:fitstreak/data/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('añadir "o extensión de tríceps" a los fondos, elegirla y quitarla', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    final n = c.read(routineProvider.notifier);
    await n.replaceWith(const Routine(title: 'Mi rutina', days: [
      RoutineDay(name: 'Upper', items: [
        RoutineItem(exerciseId: 'Dips_-_Triceps_Version', slot: 'Fondos cerrados', sets: 3, reps: '8-12', restSeconds: 75),
      ]),
    ]));

    await n.addOption(0, 0, exerciseId: 'Triceps_Pushdown', slot: 'Triceps Pushdown');
    // Repetida o la misma que ya está: no se añade otra vez.
    await n.addOption(0, 0, exerciseId: 'Triceps_Pushdown', slot: 'Triceps Pushdown');
    await n.addOption(0, 0, exerciseId: 'Dips_-_Triceps_Version', slot: 'Fondos');
    var item = c.read(routineProvider)!.days[0].items[0];
    expect(item.alternatives.map((a) => a.exerciseId), ['Triceps_Pushdown']);

    // Elegir la extensión: los fondos pasan a ser la opción.
    await n.chooseOption(0, 0, 0);
    item = c.read(routineProvider)!.days[0].items[0];
    expect(item.exerciseId, 'Triceps_Pushdown');
    expect(item.alternatives.single.exerciseId, 'Dips_-_Triceps_Version');
    expect((item.sets, item.reps, item.restSeconds), (3, '8-12', 75));

    await n.removeOption(0, 0, 0);
    expect(c.read(routineProvider)!.days[0].items[0].alternatives, isEmpty);
  });
}
