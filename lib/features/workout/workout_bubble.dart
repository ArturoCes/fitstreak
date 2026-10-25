import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/active_workout.dart';
import '../../ui/theme.dart';
import 'overlay_bubble.dart';
import 'workout_screen.dart';

/// Counts open dialogs and sheets: the bubble hides while there is one so it
/// doesn't cover its buttons.
class PopupObserver extends NavigatorObserver {
  /// Number of open popups.
  final open = ValueNotifier(0);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _change(1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _change(-1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _change(-1);
  }

  /// Adds [d] after the frame: the events arrive while the Navigator builds.
  void _change(int d) => WidgetsBinding.instance.addPostFrameCallback((_) {
        open.value = (open.value + d).clamp(0, 99);
      });
}

/// The app's popup observer (registered in the router).
final popupObserver = PopupObserver();

/// Floating bubble with the timer while a workout is running and you are on
/// another screen. It can be dragged anywhere and tapping it goes back to the
/// workout.
class WorkoutBubbleHost extends ConsumerStatefulWidget {
  /// Wraps [child]; [router] tells the current screen.
  const WorkoutBubbleHost({super.key, required this.router, required this.child});

  /// The app router.
  final GoRouter router;

  /// The rest of the app.
  final Widget child;

  @override
  ConsumerState<WorkoutBubbleHost> createState() => _WorkoutBubbleHostState();
}

/// Bubble position and the overlay controller.
class _WorkoutBubbleHostState extends ConsumerState<WorkoutBubbleHost> {
  static const _size = 76.0;
  Offset? _pos;
  late final _overlay = OverlayBubbleController(ref, onOpenWorkout: _openWorkout);

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRoute);
    _overlay.attach();
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRoute);
    _overlay.detach();
    super.dispose();
  }

  /// Rebuilds when the screen changes.
  void _onRoute() => setState(() {});

  /// Opens the workout screen unless it is already open.
  void _openWorkout() {
    if (ref.read(activeWorkoutProvider) == null) return;
    final config = widget.router.routerDelegate.currentConfiguration;
    if (config.isNotEmpty && config.last.matchedLocation == '/workout') return;
    widget.router.push('/workout');
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(activeWorkoutProvider);
    ref.listen(activeWorkoutProvider, (_, next) => _overlay.workoutChanged(next));
    // The topmost route (pushed ones don't show in the uri).
    final config = widget.router.routerDelegate.currentConfiguration;
    final path = config.isEmpty ? '' : config.last.matchedLocation;
    final show = w != null && path != '/workout' && path != '/onboarding';
    return ValueListenableBuilder(
      valueListenable: popupObserver.open,
      builder: (context, popups, _) => _layout(w, show && popups == 0),
    );
  }

  /// The app with the draggable bubble on top when [show].
  Widget _layout(ActiveWorkout? w, bool show) {
    return LayoutBuilder(builder: (context, box) {
      final media = MediaQuery.of(context);
      final maxX = box.maxWidth - _size - 8;
      final maxY = box.maxHeight - _size - media.padding.bottom - 90;
      final pos = _pos ?? Offset(maxX, maxY);
      final clamped = Offset(
        pos.dx.clamp(8, maxX < 8 ? 8 : maxX).toDouble(),
        pos.dy.clamp(media.padding.top + 8, maxY < 8 ? 8 : maxY).toDouble(),
      );
      return Stack(
        children: [
          widget.child,
          if (show)
            Positioned(
              left: clamped.dx,
              top: clamped.dy,
              child: GestureDetector(
                onPanUpdate: (d) => setState(() => _pos = clamped + d.delta),
                // When released it snaps to the nearest edge.
                onPanEnd: (_) => setState(() {
                  final c = _pos ?? clamped;
                  _pos = Offset(c.dx + _size / 2 < box.maxWidth / 2 ? 8 : maxX, c.dy);
                }),
                onTap: () => widget.router.push('/workout'),
                child: _Bubble(workout: w!, size: _size),
              ),
            ),
        ],
      );
    });
  }
}

/// In-app bubble, redrawn every second.
class _Bubble extends ConsumerWidget {
  /// Creates the bubble.
  const _Bubble({required this.workout, required this.size});

  /// The running workout.
  final ActiveWorkout workout;

  /// Diameter.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clockProvider);
    return BubbleFace(workout: workout, now: DateTime.now(), size: size);
  }
}

/// The circle with the time. Used by the in-app bubble and the one floating
/// over other apps.
class BubbleFace extends StatelessWidget {
  /// Creates the face for [workout] at time [now].
  const BubbleFace({super.key, required this.workout, required this.now, required this.size});

  /// The running workout.
  final ActiveWorkout workout;

  /// Current time.
  final DateTime now;

  /// Diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final rest = workout.restLeft(now);
    final resting = rest != null && !workout.paused;
    final color = workout.paused
        ? AppColors.orange
        : resting
            ? AppColors.tealDark
            : AppColors.teal;
    final label = workout.paused ? 'PAUSA' : (resting ? 'DESCANSO' : 'ENTRENO');
    final time = resting ? mmss(Duration(seconds: rest)) : mmss(workout.elapsed(now));
    return Material(
      color: color,
      shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 3)),
      elevation: 8,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (resting && workout.restTotal > 0)
              Padding(
                padding: const EdgeInsets.all(4),
                child: SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: (rest / workout.restTotal).clamp(0, 1).toDouble(),
                    strokeWidth: 4,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  workout.paused ? Icons.pause_rounded : Icons.fitness_center,
                  color: Colors.white,
                  size: 16,
                ),
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 8, letterSpacing: 0.6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
