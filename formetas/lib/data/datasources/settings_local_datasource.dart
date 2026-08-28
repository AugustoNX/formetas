import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/settings_entity.dart';

class SettingsLocalDataSource {
  SettingsLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'theme_mode';
  static const _onboardingKey = 'onboarding_complete';
  static const _appModeKey = 'app_mode';

  AppThemeMode getThemeMode() {
    final value = _prefs.getString(_themeKey);
    if (value == null) return AppThemeMode.system;
    return AppThemeMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _prefs.setString(_themeKey, mode.name);
  }

  AppMode getAppMode() {
    final value = _prefs.getString(_appModeKey);
    return AppMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppMode.financial,
    );
  }

  Future<void> setAppMode(AppMode mode) async {
    await _prefs.setString(_appModeKey, mode.name);
  }

  bool isOnboardingComplete() => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingComplete() async {
    await _prefs.setBool(_onboardingKey, true);
  }
}
