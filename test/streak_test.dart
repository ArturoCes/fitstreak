import 'package:fitstreak/data/streak.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int day, [int month = 10]) => DateTime(2026, month, day, 18);

void main() {
  test('descansos permitidos según días por semana', () {
    expect([2, 3, 4, 5, 6].map(maxRestDays), [5, 4, 3, 2, 2]);
  });

  test('sin entrenos no hay racha', () {
    const s = StreakState();
    expect(s.current(d(10)), 0);
    expect(s.atRisk(d(10)), isFalse);
  });

  test('entrenar suma y los descansos permitidos también cuentan', () {
    // 3 días/semana → hasta 4 días de descanso seguidos.
    var s = const StreakState().recordWorkout(d(1), daysPerWeek: 3);
    expect(s.current(d(1)), 1);
    expect(s.current(d(2)), 2); // descanso permitido
    expect(s.current(d(5)), 5);
    expect(s.atRisk(d(5)), isFalse);
    expect(s.atRisk(d(6)), isTrue); // 5º día sin entrenar: hay que entrenar

    s = s.evaluate(d(6)).recordWorkout(d(6), daysPerWeek: 3);
    expect(s.current(d(6)), 6);
    expect(s.freezes, startingFreezes);
  });

  test('si te pasas de descanso se gasta un protector', () {
    var s = const StreakState().recordWorkout(d(1), daysPerWeek: 4); // 3 descansos
    // Protegido hasta el 4; el 5 no entrena; el 6 se evalúa → protector.
    s = s.evaluate(d(6));
    expect(s.freezes, startingFreezes - 1);
    expect(s.streakStart, isNotNull);
    expect(s.current(d(6)), 5); // del 1 al 5, hoy aún en juego
    // Evaluar otra vez el mismo día no gasta más.
    expect(s.evaluate(d(6)).freezes, s.freezes);
  });

  test('4 días: martes a viernes y fin de semana largo sin gastar protectores', () {
    // 20 de octubre de 2026 es martes.
    var s = const StreakState();
    for (var day = 20; day <= 23; day++) {
      s = s.evaluate(d(day)).recordWorkout(d(day), daysPerWeek: 4);
    }
    // Sábado, domingo y lunes de descanso; el martes vuelve a entrenar.
    expect(s.atRisk(d(26)), isFalse); // lunes: aún es descanso permitido
    s = s.evaluate(d(27));
    expect(s.freezes, startingFreezes);
    expect(s.streakStart, isNotNull);
    s = s.recordWorkout(d(27), daysPerWeek: 4);
    expect(s.current(d(27)), 8);
  });

  test('una racha guardada con la regla anterior se pone al día', () {
    // Antes, con 4 días solo había 2 descansos: protegida hasta el domingo 25.
    final old = StreakState(
      streakStart: DateTime(2026, 10, 20),
      lastWorkout: DateTime(2026, 10, 23),
      protectedUntil: DateTime(2026, 10, 25),
    );
    expect(old.withRestAllowance(4).protectedUntil, DateTime(2026, 10, 26));
    // Nunca la acorta (p. ej. si un protector ya la había alargado más).
    final longer = StreakState(
      streakStart: DateTime(2026, 10, 20),
      lastWorkout: DateTime(2026, 10, 23),
      protectedUntil: DateTime(2026, 10, 28),
    );
    expect(longer.withRestAllowance(4).protectedUntil, DateTime(2026, 10, 28));
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
