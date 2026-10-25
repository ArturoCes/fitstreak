import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/active_workout.dart';
import '../../data/app_state.dart';
import 'workout_bubble.dart';

// Bubble over other apps (Android only). A second Flutter engine started at
// [overlayMain] draws it: it shares no memory with the app, so the workout is
// sent as JSON and it computes the time on its own.

const _overlayKey = 'overlay_bubble';
const _openMessage = 'open_workout';
const _tapKey = 'bubble_tapped_at';
/// Bubble diameter in logical pixels.
const bubbleDp = 76.0;

/// Whether the bubble over other apps exists on this platform.
bool get overlaySupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Whether the user turned the bubble over other apps on.
class OverlayBubbleNotifier extends Notifier<bool> {
  /// Loads the saved setting.
  @override
  bool build() => overlaySupported && (ref.read(prefsProvider).getBool(_overlayKey) ?? false);

  /// Saves the setting.
  Future<void> set(bool on) async {
    state = on;
    await ref.read(prefsProvider).setBool(_overlayKey, on);
  }
}

/// Whether the bubble over other apps is on.
final overlayBubbleProvider = NotifierProvider<OverlayBubbleNotifier, bool>(OverlayBubbleNotifier.new);

/// Turns the bubble on or off, asking for the Android permission if needed.
Future<void> toggleOverlayBubble(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(overlayBubbleProvider.notifier);
  if (ref.read(overlayBubbleProvider)) {
    await notifier.set(false);
    return;
  }
  if (!overlaySupported) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('La burbuja sobre otras apps solo existe en Android.')),
    );
    return;
  }
  if (await askOverlayPermission(context)) await notifier.set(true);
}

/// Explains what it is for and opens the Android setting. Returns whether it
/// was granted.
Future<bool> askOverlayPermission(BuildContext context) async {
  if (await FlutterOverlayWindow.isPermissionGranted()) return true;
  if (!context.mounted) return false;
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.bubble_chart_outlined, size: 40),
      title: const Text('Burbuja sobre otras apps'),
      content: const Text(
        'Para ver el temporizador mientras usas otras apps, Android pide el permiso '
        '"Mostrar sobre otras apps".\n\nEn la pantalla que se abre, busca FitStreak y actívalo.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Ahora no')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ir a ajustes')),
      ],
    ),
  );
  if (go != true) return false;
  try {
    await FlutterOverlayWindow.requestPermission();
  } catch (e) {
    debugPrint('No se pudo abrir el ajuste de superposición: $e');
  }
  return FlutterOverlayWindow.isPermissionGranted();
}

/// Shows or hides the bubble depending on whether the app is in the
/// background. Lives in [WorkoutBubbleHost], which is always mounted.
class OverlayBubbleController with WidgetsBindingObserver {
  /// Creates the controller; [onOpenWorkout] opens the workout screen.
  OverlayBubbleController(this.ref, {required this.onOpenWorkout});

  /// To read the workout and settings.
  final WidgetRef ref;

  /// Opens the workout screen.
  final VoidCallback onOpenWorkout;
  StreamSubscription<dynamic>? _messages;
  bool _shown = false;
  bool _inBackground = false;

  /// Starts listening to the app lifecycle and the bubble's messages.
  void attach() {
    if (!overlaySupported) return;
    WidgetsBinding.instance.addObserver(this);
    _messages = FlutterOverlayWindow.overlayListener.listen((m) {
      if (m == _openMessage) onOpenWorkout();
    });
  }

  /// Stops listening.
  void detach() {
    if (!overlaySupported) return;
    WidgetsBinding.instance.removeObserver(this);
    _messages?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _inBackground = false;
        _hide();
        _checkBubbleTap();
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        if (_inBackground) return;
        _inBackground = true;
        _show();
      default:
    }
  }

  /// If the app was reopened by tapping the bubble (a few seconds ago), opens
  /// the workout instead of the screen you were on.
  Future<void> _checkBubbleTap() async {
    final prefs = ref.read(prefsProvider);
    try {
      await prefs.reload();
    } catch (_) {}
    final at = prefs.getInt(_tapKey);
    if (at == null) return;
    await prefs.remove(_tapKey);
    if (DateTime.now().millisecondsSinceEpoch - at < 10000) onOpenWorkout();
  }

  /// Call when the workout changes so the bubble stays up to date.
  void workoutChanged(ActiveWorkout? w) {
    if (!_shown) return;
    if (w == null) {
      _hide();
    } else {
      _send(w);
    }
  }

  /// Shows the bubble if there is a workout, it is on and allowed.
  Future<void> _show() async {
    final w = ref.read(activeWorkoutProvider);
    if (w == null || !ref.read(overlayBubbleProvider)) return;
    try {
      if (!await FlutterOverlayWindow.isPermissionGranted()) return;
      final px = (bubbleDp * WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio).round();
      await FlutterOverlayWindow.showOverlay(
        height: px,
        width: px,
        alignment: OverlayAlignment.centerRight,
        enableDrag: true,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'FitStreak',
        overlayContent: 'Burbuja del entreno activa',
        visibility: NotificationVisibility.visibilityPublic,
      );
      _shown = true;
      // The bubble engine takes a moment to listen: send it twice.
      _send(w);
      Future.delayed(const Duration(milliseconds: 800), () {
        final now = ref.read(activeWorkoutProvider);
        if (_shown && now != null) _send(now);
      });
    } catch (e) {
      debugPrint('No se pudo mostrar la burbuja: $e');
    }
  }

  /// Closes the bubble.
  Future<void> _hide() async {
    if (!_shown) return;
    _shown = false;
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint('No se pudo cerrar la burbuja: $e');
    }
  }

  /// Sends [w] to the bubble without waiting: the plugin never replies.
  void _send(ActiveWorkout w) =>
      unawaited(FlutterOverlayWindow.shareData(jsonEncode(w.toJson())).catchError((_) => null));
}

/// Entry point of the bubble engine (see main.dart).
void runOverlayBubble() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OverlayApp());
}

/// The app the bubble engine runs: just the bubble face.
class _OverlayApp extends StatefulWidget {
  /// Creates the app.
  const _OverlayApp();

  @override
  State<_OverlayApp> createState() => _OverlayAppState();
}

/// Receives the workout and ticks every second.
class _OverlayAppState extends State<_OverlayApp> {
  ActiveWorkout? _workout;
  StreamSubscription<dynamic>? _sub;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _sub = FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is! String || data == _openMessage) return;
      try {
        setState(() => _workout = ActiveWorkout.fromJson(jsonDecode(data) as Map<String, dynamic>));
      } catch (e) {
        debugPrint('Burbuja: datos no válidos: $e');
      }
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  // The native service handles the tap (OverlayService.openHostApp in
  // packages/flutter_overlay_window): this only draws.
  @override
  Widget build(BuildContext context) {
    final w = _workout;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      home: Material(
        type: MaterialType.transparency,
        child: Center(
          child: w == null
              ? const SizedBox.square(dimension: bubbleDp - 6)
              : BubbleFace(workout: w, now: DateTime.now(), size: bubbleDp - 6),
        ),
      ),
    );
  }
}
