import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/core/providers/preferences_provider.dart';

/// Follows the device by default; the user can override to light or dark.
/// Remembered across launches.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_key);
    return ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
  }

  void setMode(ThemeMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});
