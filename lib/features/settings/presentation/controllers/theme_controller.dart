import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_theme.dart';

class ThemeState {
  final String mode;
  const ThemeState(this.mode);

  ThemeMode get themeMode => AppTheme.themeModeFromName(mode);
  bool get oled => AppTheme.isOled(mode);
}

/// MVVM ViewModel for the app theme (system / light / dark / oled).
class ThemeController extends Notifier<ThemeState> {
  static const _key = 'theme_mode';
  bool _userChanged = false;
  int _loadToken = 0;

  @override
  ThemeState build() {
    final token = ++_loadToken;
    _loadFromPrefs(token);
    return const ThemeState('system');
  }

  Future<void> _loadFromPrefs(int token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted || token != _loadToken || _userChanged) return;
      final saved = prefs.getString(_key);

      // Also check Drift settings table (older installs / settings screen).
      String? fromDb;
      try {
        fromDb = await ref.read(settingsRepositoryProvider).getThemeMode();
      } catch (_) {}

      final mode = saved ?? fromDb ?? 'system';
      if (!_userChanged && token == _loadToken) {
        state = ThemeState(mode);
      }
    } catch (_) {
      // Keep default system theme.
    }
  }

  Future<void> setMode(String mode) async {
    _userChanged = true;
    state = ThemeState(mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode);
    } catch (_) {}
    try {
      await ref.read(settingsRepositoryProvider).setThemeMode(mode);
    } catch (_) {}
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeState>(ThemeController.new);
