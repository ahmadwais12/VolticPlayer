import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/repositories.dart';
import '../database/app_database.dart';

/// Concrete [SettingsRepository] backed by SharedPreferences + Drift.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({required this.db});

  final AppDatabase db;

  /// Primary first-run flag. SharedPreferences is used so onboarding stays
  /// completed even if the Drift DB is recreated during development.
  static const _onboardingPrefsKey = 'onboarding_completed_v1';
  static const _onboardingDbKey = 'first_launch_done';

  @override
  Future<String> getThemeMode() =>
      db.settingsDao.get('theme_mode').then((v) => v ?? 'system');

  @override
  Future<void> setThemeMode(String mode) =>
      db.settingsDao.set('theme_mode', mode);

  @override
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_onboardingPrefsKey) == true) return false;

    // Migrate older installs that only wrote the Drift flag.
    final legacy = await db.settingsDao.get(_onboardingDbKey);
    if (legacy != null) {
      await prefs.setBool(_onboardingPrefsKey, true);
      return false;
    }
    return true;
  }

  @override
  Future<void> setFirstLaunchDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingPrefsKey, true);
    await db.settingsDao.set(_onboardingDbKey, '1');
  }

  @override
  Future<T?> getSetting<T>(String key, {T? defaultValue}) async {
    final v = await db.settingsDao.get(key);
    if (v == null) return defaultValue;
    if (T == bool) return (v == 'true') as T;
    if (T == int) return (int.tryParse(v) ?? defaultValue) as T;
    return v as T;
  }

  @override
  Future<void> setSetting<T>(String key, T value) =>
      db.settingsDao.set(key, value.toString());
}
