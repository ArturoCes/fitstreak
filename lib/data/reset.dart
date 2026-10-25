import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/workout/workout_bubble.dart';
import 'active_workout.dart';
import 'app_state.dart';
import 'motivation.dart';
import 'progress_state.dart';

/// Rebuilds the whole tree (and with it every provider) so the app starts
/// as if freshly installed, without closing it.
class AppRestarter extends StatefulWidget {
  /// Wraps the app built by [builder].
  const AppRestarter({super.key, required this.builder});

  /// Builds the app (the ProviderScope and everything under it).
  final WidgetBuilder builder;

  /// Restarts the app that contains [context].
  static void restart(BuildContext context) =>
      context.findAncestorStateOfType<_AppRestarterState>()?.restart();

  @override
  State<AppRestarter> createState() => _AppRestarterState();
}

/// Holds the key that is replaced to restart the app.
class _AppRestarterState extends State<AppRestarter> {
  Key _key = UniqueKey();

  /// A new key throws the old subtree away.
  void restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: Builder(builder: widget.builder));
}

/// Deletes profile, routine, streak, history, workout in progress, settings,
/// reminders and custom image, then restarts into the onboarding.
Future<void> wipeAllData(BuildContext context, WidgetRef ref) async {
  // First what lives outside the preferences.
  ref.read(activeWorkoutProvider.notifier).abandon();
  await ref.read(motivationProvider.notifier).clearImage();
  try {
    await ref.read(notificationsProvider).cancelAll();
  } catch (e) {
    debugPrint('No se pudieron cancelar las notificaciones: $e');
  }
  await ref.read(prefsProvider).clear();
  popupObserver.open.value = 0;
  if (context.mounted) AppRestarter.restart(context);
}
