import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise.dart';
import '../data/exercise_repository.dart';

/// Exercise image. Both datasets have the start and end position; with
/// [animate] they alternate like a GIF.
class ExerciseMedia extends ConsumerStatefulWidget {
  /// Creates the image of [exercise].
  const ExerciseMedia(
    this.exercise, {
    super.key,
    this.animate = false,
    this.fit = BoxFit.cover,
  });

  /// Exercise to show.
  final Exercise exercise;

  /// Alternate the frames.
  final bool animate;

  /// How photos fill the box (drawings are always contained).
  final BoxFit fit;

  @override
  ConsumerState<ExerciseMedia> createState() => _ExerciseMediaState();
}

/// Runs the frame timer while animating.
class _ExerciseMediaState extends ConsumerState<ExerciseMedia> {
  static const _frameDuration = Duration(milliseconds: 1100);

  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(ExerciseMedia old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate || old.exercise.id != widget.exercise.id) {
      _frame = 0;
      _syncTimer();
    }
  }

  /// Starts or stops the frame timer according to `animate`.
  void _syncTimer() {
    _timer?.cancel();
    _timer = widget.animate
        ? Timer.periodic(_frameDuration, (_) {
            if (mounted) setState(() => _frame++);
          })
        : null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawings = ref.watch(preferDrawingsProvider);
    final urls = widget.exercise.urlsFor(drawings: drawings);
    if (urls.isEmpty) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(child: Icon(Icons.fitness_center, color: Colors.black26)),
      );
    }
    final url = urls[_frame % urls.length];
    // Drawings are line art: cropping cuts the figure, so keep them whole.
    final fit = drawings && widget.exercise.drawings.isNotEmpty ? BoxFit.contain : widget.fit;
    Widget image(String u) => Image(
          image: CachedNetworkImageProvider(u),
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) =>
              const Center(child: Icon(Icons.fitness_center, color: Colors.black26)),
        );

    return ColoredBox(
      // Drawings are lines on white: same background for photos.
      color: Colors.white,
      child: !widget.animate || urls.length < 2
          ? image(urls.first)
          // Frames are stacked and only their opacity changes: each image
          // loads once and its download isn't cut when the frame changes.
          : Stack(
              fit: StackFit.expand,
              children: [
                for (final u in urls)
                  AnimatedOpacity(
                    opacity: u == url ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: image(u),
                  ),
              ],
            ),
    );
  }
}

/// "Fotos / Dibujos" switch that saves the preference.
class MediaStyleToggle extends ConsumerWidget {
  /// Creates the switch.
  const MediaStyleToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawings = ref.watch(preferDrawingsProvider);
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: false, icon: Icon(Icons.photo_camera_outlined), label: Text('Fotos')),
        ButtonSegment(value: true, icon: Icon(Icons.draw_outlined), label: Text('Dibujos')),
      ],
      selected: {drawings},
      onSelectionChanged: (s) => ref.read(preferDrawingsProvider.notifier).set(s.first),
    );
  }
}
