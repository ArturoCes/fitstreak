import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette inspired by the user's reference design: light background, navy
/// for text and dark blocks, teal as main color and orange as accent.
///
/// Contrast (WCAG): white text only goes on [tealDark] or darker (4.6:1);
/// on [orange] the text is [navy] (6.5:1). Colored text on a background goes
/// through [readableOn].
abstract final class AppColors {
  /// Navy: text and dark blocks in light mode.
  static const navy = Color(0xFF13293D);

  /// Teal: main color for icons, charts and accents (3:1 on both themes).
  static const teal = Color(0xFF169E78);

  /// Darker teal: filled buttons and cards with white text.
  static const tealDark = Color(0xFF0E8566);

  /// Deepest teal, end of the gradients.
  static const tealDeep = Color(0xFF0A6650);

  /// Orange: accent fills (call to action, streak, warnings).
  static const orange = Color(0xFFF7931E);

  /// Grey for secondary text (4.7:1 on white).
  static const muted = Color(0xFF6B7385);
}

/// [color] adjusted until it reads as text on the current theme's surface
/// (4.5:1): darker in light mode, lighter in dark mode. Keeps the hue, so
/// an orange warning stays orange.
Color readableOn(BuildContext context, Color color) {
  final theme = Theme.of(context);
  final background = theme.colorScheme.surface;
  final dark = theme.brightness == Brightness.dark;
  var hsl = HSLColor.fromColor(color);
  for (var i = 0; i < 20 && _contrast(hsl.toColor(), background) < 4.5; i++) {
    final l = (hsl.lightness + (dark ? 0.03 : -0.03)).clamp(0.0, 1.0);
    hsl = hsl.withLightness(l);
  }
  return hsl.toColor();
}

/// WCAG contrast ratio between [a] and [b].
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

/// Colors that change between light and dark mode.
class _Palette {
  /// Creates a palette.
  const _Palette({
    required this.background,
    required this.surface,
    required this.ink,
    required this.accent,
    required this.line,
    required this.muted,
  });

  /// Screen background.
  final Color background;

  /// Cards, sheets and dialogs.
  final Color surface;

  /// Main text.
  final Color ink;

  /// Selected chips, labels, option icons.
  final Color accent;

  /// Borders and dividers.
  final Color line;

  /// Secondary text.
  final Color muted;

  /// Light mode palette.
  static const light = _Palette(
    background: Color(0xFFF4F6F9),
    surface: Colors.white,
    ink: AppColors.navy,
    accent: AppColors.navy,
    line: Color(0xFFE6E9EF),
    muted: AppColors.muted,
  );

  /// Dark mode palette.
  static const dark = _Palette(
    background: Color(0xFF0E1822),
    surface: Color(0xFF182532),
    ink: Color(0xFFE8EEF4),
    accent: Color(0xFF4F86B8),
    line: Color(0xFF2A3a4A),
    muted: Color(0xFF9AA4B6),
  );
}

/// The app theme (Poppins, rounded cards and buttons) for [brightness].
ThemeData buildAppTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? _Palette.dark : _Palette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    brightness: brightness,
    primary: AppColors.tealDark,
    onPrimary: Colors.white,
    secondary: AppColors.orange,
    onSecondary: AppColors.navy,
    surface: p.surface,
    onSurface: p.ink,
    tertiary: p.accent,
    onTertiary: Colors.white,
  );
  final base = brightness == Brightness.dark
      ? ThemeData(brightness: Brightness.dark).textTheme
      : ThemeData().textTheme;
  final text = GoogleFonts.poppinsTextTheme(base).apply(bodyColor: p.ink, displayColor: p.ink);
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.15),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodySmall: text.bodySmall?.copyWith(color: p.muted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.ink,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: rounded,
        textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.accent,
      secondarySelectedColor: p.accent,
      checkmarkColor: Colors.white,
      // Selected chips use the dark accent: their label turns white.
      labelStyle: text.bodyMedium?.copyWith(
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : p.ink,
        ),
      ),
      secondaryLabelStyle: text.bodyMedium?.copyWith(color: Colors.white),
      side: BorderSide(color: p.line),
      shape: rounded,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      hintStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.teal.withValues(alpha: 0.2),
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dividerTheme: DividerThemeData(color: p.line),
  );
}
/// Icon inside a colored rounded square, as in the reference design.
class IconTile extends StatelessWidget {
  /// Creates a tile; tappable when [onTap] is set.
  const IconTile({
    super.key,
    required this.icon,
    this.color = AppColors.orange,
    this.size = 40,
    this.onTap,
    this.tooltip,
  });

  /// The icon.
  final IconData icon;

  /// Background color.
  final Color color;

  /// Side length in logical pixels.
  final double size;

  /// Tap action (null = not tappable).
  final VoidCallback? onTap;

  /// Accessibility label and long-press hint.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tile = Material(
      color: color,
      borderRadius: BorderRadius.circular(size * 0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(size * 0.3),
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
    return tooltip == null ? tile : Tooltip(message: tooltip!, child: tile);
  }
}

/// Orange pill with the streak ("🔥 8").
class StreakPill extends StatelessWidget {
  /// Creates the pill for a streak of [days].
  const StreakPill(this.days, {super.key});

  /// Streak length.
  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '🔥 $days',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: readableOn(context, AppColors.orange)),
      ),
    );
  }
}
