import 'package:fitstreak/data/app_state.dart';
import 'package:fitstreak/data/progress_state.dart';
import 'package:fitstreak/data/routine.dart';
import 'package:fitstreak/data/streak.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const routine = Routine(days: [
    RoutineDay(name: 'Push', items: []),
    RoutineDay(name: 'Pull', items: []),
    RoutineDay(name: 'Pierna', items: []),
    RoutineDay(name: 'Upper', items: []),
  ]);

  WorkoutLog log(int day) => WorkoutLog(
        date: DateTime(2026, 10, 20),
        dayIndex: day,
        dayName: routine.days[day].name,
        setsDone: 1,
        setsTotal: 1,
        durationSeconds: 60,
      );

  Future<ProviderContainer> container() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    await c.read(routineProvider.notifier).replaceWith(routine);
    return c;
  }

  test('sin elegir nada, sigue en orden tras el último entreno', () async {
    final c = await container();
    expect(c.read(nextDayIndexProvider), 0);
    await c.read(workoutLogsProvider.notifier).add(log(0));
    expect(c.read(nextDayIndexProvider), 1);
  });

  test('«que hoy toque» manda hasta el siguiente entreno y luego sigue desde ese día', () async {
    final c = await container();
    await c.read(workoutLogsProvider.notifier).add(log(0)); // tocaría Pull
    await c.read(dayOverrideProvider.notifier).set(0); // rutina nueva: empieza por Push
    expect(c.read(nextDayIndexProvider), 0);

    await c.read(workoutLogsProvider.notifier).add(log(0));
    expect(c.read(nextDayIndexProvider), 1);
    await c.read(workoutLogsProvider.notifier).add(log(1));
    expect(c.read(nextDayIndexProvider), 2);
  });

  test('se guarda al cerrar la app', () async {
    final c = await container();
    await c.read(dayOverrideProvider.notifier).set(3);
    final again = ProviderContainer(overrides: [prefsProvider.overrideWithValue(c.read(prefsProvider))]);
    addTearDown(again.dispose);
    expect(again.read(nextDayIndexProvider), 3);
  });
}
