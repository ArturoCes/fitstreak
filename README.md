# FitStreak

A Flutter workout app (Spanish UI) that builds a routine from your profile,
guides each workout set by set and keeps you motivated with a streak.

## Features

- **Routine generator**: days per week, goal, level, equipment (gym or home)
  and injuries decide the split and the exercises. Single days can be
  regenerated, exercises swapped, and "o …" alternatives added.
- **Import and share**: paste or open a hand-written routine (text or .docx),
  review how it was understood and save it. Routines can be shared as a code
  or published (Supabase) so others follow them and get updates.
- **Workout screen**: animated drawings, last time's sets prefilled, a
  level-up suggestion (double progression), rest timer that can be minimized,
  timed holds, and a floating bubble over other apps (Android).
- **Streak**: rest days allowed by the plan (`max(7 - daysPerWeek, 2)`),
  freezes earned by training, home screen widget and reminder notifications.
- **Progress**: per-exercise charts (max weight, estimated 1RM, volume).
- **Energy**: daily goal (Mifflin-St Jeor + activity + goal), workout
  calories, and Health Connect for steps, burned and eaten calories (e.g.
  from Fitia). Workouts are written back to Health Connect.
- **Voice summary**: "Tu resumen" for today and the week, read aloud with
  text-to-speech; reachable from icon shortcuts, `fitstreak://summary/today`
  links and nightly / Sunday notifications.

## Project layout

```
lib/
  data/        models, state (Riverpod) and pure logic: routine, streak,
               progression, energy, import/share, sync
  features/    screens, one folder per area
  services/    notifications and the home screen widget
  ui/          theme and shared widgets
android/       MainActivity (shares, links), streak widget, shortcuts
packages/      vendored flutter_overlay_window (native bubble tap)
supabase/      schema and the short-link edge function
assets/data/   exercise catalog, Spanish instructions, drawings map, quotes
tool/          scripts used to build the assets
test/          unit and widget tests
```

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Android release APKs:

```bash
flutter build apk --release --split-per-abi
```

Health Connect needs Android 8.0+ (minSdk 26) and the Health Connect app.

## Credits

Exercise data from [free-exercise-db](https://github.com/yuhonas/free-exercise-db)
(public domain) and drawings by [Everkinetic](https://github.com/everkinetic/data)
(CC BY-SA). Poppins font under the SIL Open Font License.
