// Approximate calories: basal metabolism (Mifflin-St Jeor), daily goal for
// the user's objective and active calories of a strength session (METs).
// These are estimates; with Health Connect the watch's data is used instead.

import 'user_profile.dart';

/// Basal metabolic rate in kcal/day (Mifflin-St Jeor). Without a sex, the
/// average of both formulas is used.
double basalKcal(UserProfile p) {
  final base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age;
  return base +
      switch (p.sex) {
        Sex.male => 5,
        Sex.female => -161,
        Sex.unspecified => -78,
      };
}

/// Activity multiplier for the number of training days per week.
double activityFactor(int daysPerWeek) => switch (daysPerWeek) {
      <= 2 => 1.375,
      3 => 1.45,
      4 => 1.5,
      5 => 1.55,
      _ => 1.65,
    };

/// Adjustment over maintenance for the goal (deficit or surplus, in kcal).
int goalAdjustment(Goal g) => switch (g) {
      Goal.fatLoss => -400,
      Goal.muscle => 250,
      Goal.strength => 150,
      Goal.health => 0,
    };

/// Estimated total daily energy expenditure (maintenance).
int maintenanceKcal(UserProfile p) => (basalKcal(p) * activityFactor(p.daysPerWeek)).round();

/// Calories to eat per day for the profile's goal.
int dailyGoalKcal(UserProfile p) {
  final goal = maintenanceKcal(p) + goalAdjustment(p.goal);
  // Never below basal: eating less than that is not safe.
  return goal < basalKcal(p) ? basalKcal(p).round() : goal;
}

/// Average MET of a weights session (sets + rests). The 1 subtracted in
/// [workoutKcal] is what the body burns at rest, so only active calories
/// remain.
const strengthMet = 5.0;

/// Approximate active calories of a strength session.
int workoutKcal({required double weightKg, required int durationSeconds}) =>
    ((strengthMet - 1) * weightKg * durationSeconds / 3600).round();
