import 'package:fitstreak/data/app_state.dart';
import 'package:fitstreak/features/onboarding/onboarding_screen.dart';
import 'package:fitstreak/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> open(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(theme: buildAppTheme(Brightness.light), home: const OnboardingScreen()),
    ));
  }

  Future<void> next(WidgetTester tester) => tester.tap(find.text('Siguiente'));

  testWidgets('dos toques rápidos en Siguiente no desincronizan la página', (tester) async {
    await open(tester);
    await tester.tap(find.text('Hombre'));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '30');
    await tester.enterText(fields.at(1), '175');
    await tester.enterText(fields.at(2), '75');
    await tester.pump();
    await next(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ganar músculo'));
    await tester.tap(find.text('Principiante'));
    await tester.pump();
    await next(tester);
    await tester.pump(const Duration(milliseconds: 50));
    await next(tester); // Mid-animation.
    await tester.pumpAndSettle();
    expect(find.text('Paso 4 de 6'), findsOneWidget);
    expect(find.text('¿Dónde entrenas?'), findsOneWidget);

    // A selected equipment chip keeps a readable (white) label.
    await tester.tap(find.text('Gimnasio'));
    await tester.pumpAndSettle();
    final label = tester.widget<RawChip>(find.ancestor(of: find.text('Barra'), matching: find.byType(RawChip)));
    expect(label.selected, isTrue);
    final style = DefaultTextStyle.of(tester.element(find.text('Barra'))).style;
    expect(style.color, Colors.white);
  });

  testWidgets('la edad no admite más de 3 cifras y avisa del rango', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, '9999999');
    await tester.pump();
    expect(find.text('999'), findsOneWidget);
    expect(find.text('Entre 14 y 99 años'), findsOneWidget);
  });
}
