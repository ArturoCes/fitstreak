import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise.dart';
import '../data/exercise_repository.dart';

/// Imagen del ejercicio. Los dos datasets traen la posición inicial y la
/// final; con [animate] se alternan como si fuera un GIF.
class ExerciseMedia extends ConsumerStatefulWidget {
  const ExerciseMedia(
    this.exercise, {
    super.key,
    this.animate = false,
    this.fit = BoxFit.cover,
  });

  final Exercise exercise;
  final bool animate;
  final BoxFit fit;

  @override
  ConsumerState<ExerciseMedia> createState() => _ExerciseMediaState();
}

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
    // Los dibujos son de línea: recortarlos corta la figura, mejor enteros.
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
      // Los dibujos son de línea sobre blanco: mismo fondo para las fotos.
      color: Colors.white,
      child: !widget.animate || urls.length < 2
          ? image(urls.first)
          // Los fotogramas se apilan y solo cambia la opacidad: cada imagen se
          // carga una vez y no se corta su descarga al pasar de fotograma.
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

/// Selector "Fotos / Dibujos" que guarda la preferencia.
class MediaStyleToggle extends ConsumerWidget {
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
