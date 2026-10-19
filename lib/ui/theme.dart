import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta inspirada en la referencia: fondo claro, azul marino para textos y
/// bloques oscuros, verde turquesa como color principal y naranja de acento.
abstract final class AppColors {
  static const navy = Color(0xFF13293D);
  static const teal = Color(0xFF1FAE84);
  static const tealDark = Color(0xFF168A68);
  static const orange = Color(0xFFF7931E);
  static const muted = Color(0xFF8A94A6);
}

/// Colores que cambian entre modo claro y oscuro.
class _Palette {
  const _Palette({
    required this.background,
    required this.surface,
    required this.ink,
    required this.accent,
    required this.line,
  });

  final Color background;
  final Color surface;
  final Color ink; // texto principal
  final Color accent; // chips seleccionados, etiquetas, iconos de opciones
  final Color line;

  static const light = _Palette(
    background: Color(0xFFF4F6F9),
    surface: Colors.white,
    ink: AppColors.navy,
    accent: AppColors.navy,
    line: Color(0xFFE6E9EF),
  );

  static const dark = _Palette(
    background: Color(0xFF0E1822),
    surface: Color(0xFF182532),
    ink: Color(0xFFE8EEF4),
    accent: Color(0xFF4F86B8),
    line: Color(0xFF2A3a4A),
  );
}

ThemeData buildAppTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? _Palette.dark : _Palette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    brightness: brightness,
    primary: AppColors.teal,
    onPrimary: Colors.white,
    secondary: AppColors.orange,
    onSecondary: Colors.white,
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
      bodySmall: text.bodySmall?.copyWith(color: AppColors.muted),
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
      labelStyle: text.bodyMedium?.copyWith(color: p.ink),
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
/// Icono dentro de un cuadrado redondeado de color, como en la referencia.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.color = AppColors.orange,
    this.size = 40,
    this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;
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

/// Pastilla naranja con la racha.
class StreakPill extends StatelessWidget {
  const StreakPill(this.days, {super.key});

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
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.orange),
      ),
    );
  }
}
