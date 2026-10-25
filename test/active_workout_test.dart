import 'package:fitstreak/data/active_workout.dart';
import 'package:fitstreak/data/routine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 19, 18);
  const item = RoutineItem(exerciseId: 'a', slot: 'Pecho', sets: 2, reps: '8-12', restSeconds: 60);

  ActiveWorkout workout() => ActiveWorkout(
        dayIndex: 0,
        dayName: 'Torso',
        items: const [item, item],
        sets: const [
          [SetEntry(reps: 8, kg: 20, done: true), SetEntry(reps: 8, kg: 20)],
          [SetEntry(reps: 10), SetEntry(reps: 10)],
        ],
        startedAt: start,
      );

  test('el tiempo en pausa no cuenta', () {
    final w = workout().copyWith(
      pausedTotal: const Duration(minutes: 5),
      pausedAt: () => start.add(const Duration(minutes: 20)),
    );
    expect(w.elapsed(start.add(const Duration(hours: 1))), const Duration(minutes: 15));
  });

  test('el descanso se congela al pausar y caduca al acabar', () {
    final w = workout().copyWith(restEndsAt: () => start.add(const Duration(seconds: 60)), restTotal: 60);
    expect(w.restLeft(start.add(const Duration(seconds: 15))), 45);
    expect(w.restLeft(start.add(const Duration(seconds: 61))), isNull);
    final paused = w.copyWith(pausedAt: () => start, restRemainingOnPause: () => 30);
    expect(paused.restLeft(start.add(const Duration(hours: 1))), 30);
  });

  test('cuenta series y la que toca', () {
    final w = workout();
    expect(w.setsDone, 1);
    expect(w.setsTotal, 4);
    expect(w.currentSet, 1);
    expect(w.exerciseDone(0), isFalse);
  });

  test('se guarda y se recupera igual', () {
    final w = workout().copyWith(exercise: 1, restEndsAt: () => start, restTotal: 60);
    final back = ActiveWorkout.fromJson(w.toJson());
    expect(back.exercise, 1);
    expect(back.sets[0][0].kg, 20);
    expect(back.sets[0][0].done, isTrue);
    expect(back.restEndsAt, start);
    expect(back.items.first.restSeconds, 60);
  });
}
