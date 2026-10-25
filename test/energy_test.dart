import 'package:fitstreak/data/energy.dart';
import 'package:fitstreak/data/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _p({Sex sex = Sex.male, Goal goal = Goal.health, int days = 4, double kg = 75}) => UserProfile(
      age: 25,
      sex: sex,
      heightCm: 175,
      weightKg: kg,
      goal: goal,
      level: Level.intermediate,
      daysPerWeek: days,
      minutesPerSession: 60,
      place: Place.gym,
      equipment: const {},
      injuries: const {},
    );

void main() {
  test('basal de Mifflin-St Jeor', () {
    // 10·75 + 6,25·175 − 5·25 = 1718,75
    expect(basalKcal(_p()), closeTo(1723.75, 0.01)); // +5 hombre
    expect(basalKcal(_p(sex: Sex.female)), closeTo(1557.75, 0.01)); // −161 mujer
    expect(basalKcal(_p(sex: Sex.unspecified)), closeTo(1640.75, 0.01)); // media
  });

  test('meta según objetivo y días de entreno', () {
    final maintenance = maintenanceKcal(_p()); // 1723,75 × 1,5
    expect(maintenance, 2586);
    expect(dailyGoalKcal(_p(goal: Goal.fatLoss)), maintenance - 400);
    expect(dailyGoalKcal(_p(goal: Goal.muscle)), maintenance + 250);
    expect(maintenanceKcal(_p(days: 2)), lessThan(maintenance));
  });

  test('la meta nunca baja del basal', () {
    final tiny = UserProfile(
      age: 70,
      sex: Sex.female,
      heightCm: 150,
      weightKg: 40,
      goal: Goal.fatLoss,
      level: Level.beginner,
      daysPerWeek: 2,
      minutesPerSession: 30,
      place: Place.home,
      equipment: const {},
      injuries: const {},
    );
    expect(dailyGoalKcal(tiny), greaterThanOrEqualTo(basalKcal(tiny).round()));
  });

  test('calorías de un entreno de pesas', () {
    // (5 − 1) MET × 75 kg × 1 h = 300 kcal
    expect(workoutKcal(weightKg: 75, durationSeconds: 3600), 300);
    expect(workoutKcal(weightKg: 75, durationSeconds: 1800), 150);
  });

  test('el sexo se guarda y los perfiles antiguos no fallan', () {
    final back = UserProfile.fromJson(_p(sex: Sex.female).toJson());
    expect(back.sex, Sex.female);
    final old = _p().toJson()..remove('sex');
    expect(UserProfile.fromJson(old).sex, Sex.unspecified);
  });
}
