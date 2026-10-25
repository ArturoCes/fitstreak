import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../data/progress_state.dart';
import '../catalog/catalog_screen.dart';
import '../progress/progress_screen.dart';
import '../routine/routine_screen.dart';
import '../routine/sync_ui.dart';
import '../streak/streak_screen.dart';

/// Main screen with the four tabs: routine, progress, streak and exercises.
class HomeScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Selected tab, plus the reminder sync and the followed-routine update
/// check on start and resume.
class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  DateTime? _lastUpdateCheck;

  @override
  void initState() {
    super.initState();
    // Schedules (or removes) tonight's "streak at risk" alert.
    ref.read(streakProvider.notifier).syncReminders();
    // Profile without a routine (e.g. half-written data): generate one
    // instead of leaving the screen loading.
    if (ref.read(routineProvider) == null && ref.read(profileProvider) != null) {
      ref.read(routineProvider.notifier).regenerate();
    }
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRoutineUpdate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkRoutineUpdate();
  }

  /// On app start (and on resume, at most every 10 minutes): did the author
  /// change the routine I follow?
  void _checkRoutineUpdate() {
    final now = DateTime.now();
    if (_lastUpdateCheck case final last? when now.difference(last) < const Duration(minutes: 10)) return;
    _lastUpdateCheck = now;
    if (mounted) promptRoutineUpdate(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final atRisk = ref.watch(streakProvider).atRisk(DateTime.now());
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [RoutineScreen(), ProgressScreen(), StreakScreen(), CatalogScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.event_note), label: 'Rutina'),
          const NavigationDestination(icon: Icon(Icons.insights), label: 'Progreso'),
          NavigationDestination(
            icon: Badge(isLabelVisible: atRisk, child: const Icon(Icons.local_fire_department)),
            label: 'Racha',
          ),
          const NavigationDestination(icon: Icon(Icons.search), label: 'Ejercicios'),
        ],
      ),
    );
  }
}
