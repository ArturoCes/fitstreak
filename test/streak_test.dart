import 'package:fitstreak/data/streak.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int day, [int month = 10]) => DateTime(2026, month, day, 18);

void main() {
  test('descansos permitidos según días por semana', () {
    expect([2, 3, 4, 5, 6].map(maxRestDays), [4, 3, 2, 2, 2]);
  });

  test('sin entrenos no hay racha', () {
    const s = StreakState();
    expect(s.current(d(10)), 0);
    expect(s.atRisk(d(10)), isFalse);
  });

  test('entrenar suma y los descansos permitidos también cuentan', () {
    // 3 días/semana → hasta 3 días de descanso seguidos.
    var s = const StreakState().recordWorkout(d(1), daysPerWeek: 3);
    expect(s.current(d(1)), 1);
    expect(s.current(d(2)), 2); // descanso permitido
    expect(s.current(d(4)), 4);
    expect(s.atRisk(d(4)), isFalse);
    expect(s.atRisk(d(5)), isTrue); // 4º día sin entrenar: hay que entrenar

    s = s.evaluate(d(5)).recordWorkout(d(5), daysPerWeek: 3);
    expect(s.current(d(5)), 5);
    expect(s.freezes, startingFreezes);
  });

  test('si te pasas de descanso se gasta un protector', () {
    var s = const StreakState().recordWorkout(d(1), daysPerWeek: 4); // 2 descansos
    // Protegido hasta el 3; el 4 no entrena; el 5 se evalúa → protector.
    s = s.evaluate(d(5));
    expect(s.freezes, startingFreezes - 1);
    expect(s.streakStart, isNotNull);
    expect(s.current(d(5)), 4); // del 1 al 4, hoy aún en juego
    // Evaluar otra vez el mismo día no gasta más.
    expect(s.evaluate(d(5)).freezes, s.freezes);
  });

  test('sin protectores la racha se rompe pero se guarda la mejor', () {
    var s = const StreakState(freezes: 0)
        .recordWorkout(d(1), daysPerWeek: 4)
        .recordWorkout(d(2), daysPerWeek: 4);
    expect(s.best, 2);
    s = s.evaluate(d(10));
    expect(s.streakStart, isNull);
    expect(s.current(d(10)), 0);
    expect(s.best, 2);

    s = s.recordWorkout(d(10), daysPerWeek: 4);
    expect(s.current(d(10)), 1);
  });

  test('cada 7 días se gana un protector, con un máximo', () {
    var s = const StreakState(freezes: 0);
    for (var day = 1; day <= 21; day++) {
      s = s.recordWorkout(d(day), daysPerWeek: 6);
    }
    expect(s.current(d(21)), 21);
    expect(s.freezes, maxFreezes); // 3 ganados, tope 2
    // Entrenar dos veces el mismo día no da premios extra.
    final again = s.recordWorkout(d(21), daysPerWeek: 6);
    expect(again.freezes, s.freezes);
    expect(again.current(d(21)), 21);
  });

  test('el cambio de hora no descuadra los días', () {
    // 25 de octubre de 2026: cambio de horario en Europa.
    expect(daysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
    expect(daysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
  });

  test('se guarda y se recupera', () {
    final s = const StreakState().recordWorkout(d(3), daysPerWeek: 3);
    final back = StreakState.fromJson(s.toJson());
    expect(back.current(d(4)), s.current(d(4)));
    expect(back.workoutDays, s.workoutDays);
    expect(back.protectedUntil, s.protectedUntil);
  });
}
