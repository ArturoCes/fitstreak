import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/app_state.dart';
import 'data/settings_state.dart';
import 'features/catalog/exercise_detail_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/progress/exercise_progress_screen.dart';
import 'features/workout/workout_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Sin esto, los textos se miden con la fuente de respaldo y algunos chips
  // quedan cortados cuando llega Poppins.
  await GoogleFonts.pendingFonts([
    GoogleFonts.poppins(),
    GoogleFonts.poppins(fontWeight: FontWeight.w600),
    GoogleFonts.poppins(fontWeight: FontWeight.w700),
  ]);
  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const FitStreakApp(),
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // Sin perfil no hay rutina: primero el onboarding.
    redirect: (_, state) {
      final hasProfile = ref.read(profileProvider) != null;
      if (!hasProfile && state.matchedLocation != '/onboarding') {
        return '/onboarding';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/workout/:day',
        builder: (_, state) =>
            WorkoutScreen(dayIndex: int.parse(state.pathParameters['day']!)),
      ),
      GoRoute(
        path: '/progress/:id',
        builder: (_, state) => ExerciseProgressScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/exercise/:id',
        builder: (_, state) =>
            ExerciseDetailScreen(id: state.pathParameters['id']!),
      ),
    ],
  );
});

class FitStreakApp extends ConsumerWidget {
  const FitStreakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'FitStreak',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
