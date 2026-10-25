import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/app_state.dart';
import 'data/reset.dart';
import 'data/settings_state.dart';
import 'data/sync/supabase_sync_api.dart';
import 'features/catalog/exercise_detail_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/progress/exercise_progress_screen.dart';
import 'features/routine/import_screen.dart';
import 'features/routine/search_screen.dart';
import 'features/routine/share_receiver.dart';
import 'features/summary/summary_scheduler.dart';
import 'features/summary/summary_screen.dart';
import 'features/workout/overlay_bubble.dart';
import 'features/workout/workout_bubble.dart';
import 'features/workout/workout_screen.dart';
import 'services/home_widget_sync.dart';
import 'ui/theme.dart';

/// Loads preferences, Supabase and the bundled fonts, then starts the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Poppins ships inside the app (google_fonts/ folder): never downloaded.
  GoogleFonts.config.allowRuntimeFetching = false;
  final prefs = await SharedPreferences.getInstance();
  // Published and followed routines. No connection needed to start.
  try {
    await initSupabase();
  } catch (e) {
    debugPrint('Supabase no disponible: $e');
  }
  // Wait for the font so text isn't measured with the fallback one (on the
  // web it cut chips short). If it fails or is slow, start anyway: an error
  // here would leave the app frozen on the splash screen.
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.poppins(),
      GoogleFonts.poppins(fontWeight: FontWeight.w500),
      GoogleFonts.poppins(fontWeight: FontWeight.w600),
      GoogleFonts.poppins(fontWeight: FontWeight.w700),
    ]).timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('Fuentes no disponibles al arrancar: $e');
  }
  runApp(
    AppRestarter(
      builder: (_) => ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const FitStreakApp(),
      ),
    ),
  );
}

/// Separate engine that draws the bubble over other apps (Android).
@pragma('vm:entry-point')
void overlayMain() => runOverlayBubble();

/// The app's routes. Without a profile everything goes to the onboarding.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    observers: [popupObserver],
    // No profile means no routine: onboarding first.
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
      GoRoute(path: '/workout', builder: (_, _) => const WorkoutScreen()),
      GoRoute(
        path: '/summary',
        builder: (_, state) => SummaryScreen(
          // Keyed by URL: opening another summary from outside rebuilds it.
          key: ValueKey(state.uri.toString()),
          week: state.uri.queryParameters['week'] == '1',
          speak: state.uri.queryParameters['speak'] == '1',
        ),
      ),
      GoRoute(
        path: '/import',
        builder: (_, state) => ImportRoutineScreen(initialText: state.extra as String?),
      ),
      GoRoute(path: '/search', builder: (_, _) => const SearchRoutinesScreen()),
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

/// Root widget: theme, router and the global layers (shared text
/// receiver, summary scheduler and workout bubble).
class FitStreakApp extends ConsumerWidget {
  /// Creates the app.
  const FitStreakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    ref.watch(homeWidgetSyncProvider);
    return MaterialApp.router(
      title: 'FitStreak',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      builder: (_, child) => SharedTextReceiver(
        router: router,
        child: SummaryScheduler(
          router: router,
          child: WorkoutBubbleHost(router: router, child: child!),
        ),
      ),
    );
  }
}
