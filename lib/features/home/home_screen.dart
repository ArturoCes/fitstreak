import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../data/progress_state.dart';
import '../catalog/catalog_screen.dart';
import '../routine/routine_screen.dart';
import '../streak/streak_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Programa (o quita) el aviso de "racha en peligro" de esta noche.
    ref.read(streakProvider.notifier).syncReminders();
    // Perfil sin rutina (p. ej. datos a medias): la generamos en vez de
    // dejar la pantalla cargando.
    if (ref.read(routineProvider) == null && ref.read(profileProvider) != null) {
      ref.read(routineProvider.notifier).regenerate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final atRisk = ref.watch(streakProvider).atRisk(DateTime.now());
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [RoutineScreen(), StreakScreen(), CatalogScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.event_note), label: 'Rutina'),
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
