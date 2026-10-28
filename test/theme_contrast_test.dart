import 'dart:math';

import 'package:fitstreak/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  test('el texto blanco y azul marino se leen sobre los rellenos de color', () {
    expect(contrast(Colors.white, AppColors.tealDark), greaterThanOrEqualTo(4.5));
    expect(contrast(Colors.white, AppColors.tealDeep), greaterThanOrEqualTo(4.5));
    expect(contrast(AppColors.navy, AppColors.orange), greaterThanOrEqualTo(4.5));
    expect(contrast(AppColors.muted, Colors.white), greaterThanOrEqualTo(4.5));
  });

  for (final brightness in Brightness.values) {
    testWidgets('readableOn da texto legible en tema ${brightness.name}', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(brightness),
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ));
      final surface = Theme.of(ctx).colorScheme.surface;
      for (final c in [AppColors.orange, AppColors.teal, AppColors.tealDark]) {
        expect(contrast(readableOn(ctx, c), surface), greaterThanOrEqualTo(4.5), reason: '$c');
      }
    });
  }
}
