import 'package:fitstreak/data/streak.dart';
import 'package:fitstreak/services/home_widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WorkoutLog log(DateTime d, int sets) =>
      WorkoutLog(date: d, dayIndex: 0, dayName: 'Push', setsDone: sets, setsTotal: sets, durationSeconds: 60);

  test('el widget recibe fechas de la racha y las series de los últimos días', () {
    final now = DateTime(2026, 10, 20, 18);
    final streak = const StreakState().recordWorkout(DateTime(2026, 10, 20, 16), daysPerWeek: 4);
    final data = homeWidgetData(
      streak: streak,
      logs: [log(DateTime(2026, 10, 1), 9), log(DateTime(2026, 10, 20, 9), 10), log(DateTime(2026, 10, 20, 19), 9)],
      nextDay: 'Pull',
      now: now,
    );
    expect(data['streak_start'], '2026-10-20');
    expect(data['last_workout'], '2026-10-20');
    expect(data['protected_until'], '2026-10-23'); // 4 días/semana → 3 descansos
    expect(data['day_sets'], '2026-10-20=19', reason: 'dos entrenos el mismo día se suman; los viejos no van');
    expect(data['next_day'], 'Pull');
  });

  test('sin racha van vacíos', () {
    final data = homeWidgetData(streak: const StreakState(), logs: const [], nextDay: null, now: DateTime(2026, 10, 20));
    expect((data['streak_start'], data['day_sets'], data['next_day']), ('', '', ''));
  });
}
