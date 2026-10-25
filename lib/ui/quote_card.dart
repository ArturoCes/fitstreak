import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/motivation.dart';
import 'theme.dart';

/// Quote of the day over a background drawn in code (or the user's image).
/// Tapping moves to the next one; the gear opens the settings.
class QuoteCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const QuoteCard({super.key, this.height = 190});

  /// Card height.
  final double height;

  @override
  ConsumerState<QuoteCard> createState() => _QuoteCardState();
}

/// Holds how many quotes the user skipped today.
class _QuoteCardState extends ConsumerState<QuoteCard> {
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(motivationProvider);
    final quotes = ref.watch(quotesProvider).value;
    if (quotes == null) return const SizedBox.shrink();
    if (settings.taste == null) return const _TasteQuestion();

    final quote = quoteOfTheDay(quotes, settings.taste, DateTime.now(), offset: _offset);
    if (quote == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: widget.height,
        child: Material(
          color: Colors.black,
          child: InkWell(
            onTap: () => setState(() => _offset++),
            child: Stack(
              fit: StackFit.expand,
              children: [
                QuoteBackground(kind: quote.kind, seed: _offset, imagePath: settings.imagePath),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Tag(quote.kind == QuoteKind.anime ? '🍥 ANIME' : '🎬 PELI'),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Ajustes de frases',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => showMotivationSettings(context),
                            icon: const Icon(Icons.tune, color: Colors.white70, size: 20),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '“${quote.text}”',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge?.copyWith(
                          color: Colors.white,
                          height: 1.2,
                          fontStyle: FontStyle.italic,
                          shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '— ${quote.who} · ${quote.from}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small "ANIME" / "PELI" label.
class _Tag extends StatelessWidget {
  /// Creates the label.
  const _Tag(this.label);

  /// Text of the label.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
      ),
    );
  }
}

/// First-time question for users who had the app before quotes existed.
class _TasteQuestion extends ConsumerWidget {
  /// Creates the question.
  const _TasteQuestion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Qué te motiva más?', style: text.titleMedium),
            Text('Te enseñaremos una frase cada día.', style: text.bodySmall),
            const SizedBox(height: 12),
            TastePicker(onPicked: (t) => ref.read(motivationProvider.notifier).setTaste(t)),
          ],
        ),
      ),
    );
  }
}

/// The four taste options as chips.
class TastePicker extends StatelessWidget {
  /// Creates the picker.
  const TastePicker({super.key, this.selected, required this.onPicked});

  /// The current taste (highlighted).
  final MotivationTaste? selected;

  /// Called with the chosen taste.
  final ValueChanged<MotivationTaste> onPicked;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in MotivationTaste.values)
          ChoiceChip(
            label: Text('${t.emoji} ${t.label}'),
            selected: selected == t,
            showCheckmark: false,
            labelStyle: TextStyle(
              color: selected == t ? Colors.white : Theme.of(context).colorScheme.onSurface,
            ),
            onSelected: (_) => onPicked(t),
          ),
      ],
    );
  }
}

/// Opens the quote settings: taste and background image.
Future<void> showMotivationSettings(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _MotivationSheet(),
    );

/// The quote settings sheet.
class _MotivationSheet extends ConsumerWidget {
  /// Creates the sheet.
  const _MotivationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(motivationProvider);
    final notifier = ref.read(motivationProvider.notifier);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Frases motivadoras', style: text.titleLarge),
            const SizedBox(height: 12),
            TastePicker(selected: settings.taste, onPicked: notifier.setTaste),
            const SizedBox(height: 20),
            Text('Fondo', style: text.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const IconTile(icon: Icons.photo_library_outlined, color: AppColors.teal, size: 36),
              title: Text(settings.imagePath == null ? 'Usar una imagen mía' : 'Cambiar mi imagen'),
              subtitle: const Text('Elige una foto o fondo de tu galería'),
              onTap: () async {
                final ok = await notifier.pickImage();
                if (ok && context.mounted) Navigator.pop(context);
              },
            ),
            if (settings.imagePath != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const IconTile(icon: Icons.auto_awesome, color: AppColors.orange, size: 36),
                title: const Text('Volver a los fondos de la app'),
                onTap: () {
                  notifier.clearImage();
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Card background: the user's image, or a drawing for the quote kind.
class QuoteBackground extends StatelessWidget {
  /// Creates the background.
  const QuoteBackground({super.key, required this.kind, required this.seed, this.imagePath});

  /// Anime (speed lines) or film (film frame).
  final QuoteKind kind;

  /// Picks the color variant.
  final int seed;

  /// The user's own image, used instead of the drawing.
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path != null) {
      final img = kIsWeb
          ? Image.network(path, fit: BoxFit.cover)
          : Image.file(File(path), fit: BoxFit.cover);
      return Stack(
        fit: StackFit.expand,
        children: [
          img,
          // Darkens the text area so it is always readable.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33000000), Color(0xCC000000)],
              ),
            ),
          ),
        ],
      );
    }
    return CustomPaint(
      painter: kind == QuoteKind.anime ? SpeedLinesPainter(seed) : FilmPainter(seed),
    );
  }
}

/// Manga-style speed lines with a dot screentone.
class SpeedLinesPainter extends CustomPainter {
  /// Creates the painter; [seed] picks the palette and line jitter.
  SpeedLinesPainter(this.seed);

  /// Palette and randomness seed.
  final int seed;

  static const _palettes = [
    [Color(0xFFFF6B35), Color(0xFFD7263D)], // shōnen sunset
    [Color(0xFF5B5BD6), Color(0xFF1B1B3A)], // night
    [Color(0xFF1FAE84), Color(0xFF0B3D2E)], // the app's green
    [Color(0xFFF7931E), Color(0xFF6A1B9A)], // super saiyan
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final colors = _palettes[seed % _palettes.length];
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(rect),
    );

    // Lines from a point off center, like an action panel.
    final rnd = Random(seed);
    final center = Offset(size.width * 0.8, size.height * 0.3);
    final radius = size.longestSide * 1.4;
    final line = Paint()..color = Colors.white.withValues(alpha: 0.13);
    for (var i = 0; i < 90; i++) {
      final a = i / 90 * 2 * pi + rnd.nextDouble() * 0.03;
      final w = 0.004 + rnd.nextDouble() * 0.012;
      final inner = 30 + rnd.nextDouble() * 60;
      final path = Path()
        ..moveTo(center.dx + cos(a) * inner, center.dy + sin(a) * inner)
        ..lineTo(center.dx + cos(a - w) * radius, center.dy + sin(a - w) * radius)
        ..lineTo(center.dx + cos(a + w) * radius, center.dy + sin(a + w) * radius)
        ..close();
      canvas.drawPath(path, line);
    }

    // Dot screentone in the bottom-left corner.
    final dot = Paint()..color = Colors.black.withValues(alpha: 0.22);
    const step = 9.0;
    for (var y = size.height * 0.45; y < size.height; y += step) {
      for (var x = 0.0; x < size.width * 0.6; x += step) {
        final fade = (1 - x / (size.width * 0.6)) * ((y - size.height * 0.45) / (size.height * 0.55));
        if (fade <= 0) continue;
        canvas.drawCircle(Offset(x + (y ~/ step).isOdd.toInt() * step / 2, y), 2.6 * fade, dot);
      }
    }
  }

  @override
  bool shouldRepaint(SpeedLinesPainter old) => old.seed != seed;
}

/// Film frame: spotlight, grain and sprocket holes.
class FilmPainter extends CustomPainter {
  /// Creates the painter; [seed] picks the tint and grain.
  FilmPainter(this.seed);

  /// Tint and randomness seed.
  final int seed;

  static const _tints = [
    Color(0xFFE0A458), // gold
    Color(0xFF4FA3D9), // night blue
    Color(0xFFD9534F), // action red
    Color(0xFF8BC34A), // Matrix green
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final tint = _tints[seed % _tints.length];
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0D0D0F));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.6, -0.4),
          radius: 1.1,
          colors: [tint.withValues(alpha: 0.75), tint.withValues(alpha: 0.12), Colors.transparent],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );

    // Projector light beam.
    final beam = Path()
      ..moveTo(size.width * 1.05, -10)
      ..lineTo(size.width * 0.25, size.height)
      ..lineTo(size.width * 0.55, size.height)
      ..close();
    canvas.drawPath(beam, Paint()..color = Colors.white.withValues(alpha: 0.05));

    // Grain.
    final rnd = Random(seed + 7);
    final grain = Paint();
    for (var i = 0; i < 500; i++) {
      grain.color = Colors.white.withValues(alpha: rnd.nextDouble() * 0.08);
      canvas.drawCircle(Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height), 0.8, grain);
    }

    // Film strips with sprocket holes at the top and bottom.
    const band = 14.0;
    final strip = Paint()..color = Colors.black;
    final hole = Paint()..color = Colors.white.withValues(alpha: 0.18);
    for (final y in [0.0, size.height - band]) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, band), strip);
      for (var x = 6.0; x < size.width; x += 18) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y + 4, 9, 6), const Radius.circular(1.5)),
          hole,
        );
      }
    }
  }

  @override
  bool shouldRepaint(FilmPainter old) => old.seed != seed;
}

/// Booleans as 0/1, to offset every other screentone row.
extension on bool {
  /// 1 for true, 0 for false.
  int toInt() => this ? 1 : 0;
}
