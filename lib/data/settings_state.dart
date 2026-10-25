import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';

const _themeKey = 'theme_mode';

/// Light, dark or follow-the-system theme, saved in preferences.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  /// Loads the saved theme (system by default).
  @override
  ThemeMode build() {
    final saved = ref.read(prefsProvider).getString(_themeKey);
    return ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
  }

  /// Applies and saves [mode].
  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(prefsProvider).setString(_themeKey, mode.name);
  }
}

/// The app's theme mode.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
