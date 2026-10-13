import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preferences (theme mode, locale, notification toggle).
///
/// Bug fixed: these used to live only in memory, so the dark-mode switch and
/// language picker silently reset on every cold start. They are now persisted
/// with `shared_preferences` and restored before the first frame.
class AppState {
  static const String _kTheme = 'brightly.theme';
  static const String _kLocale = 'brightly.locale';
  static const String _kNotifications = 'brightly.notifications';

  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.light);
  static final ValueNotifier<Locale> localeNotifier =
      ValueNotifier(const Locale('en'));
  static final ValueNotifier<bool> pushNotificationsEnabled =
      ValueNotifier(true);

  static SharedPreferences? _prefs;

  /// Load persisted preferences. Call before `runApp`.
  static Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('AppState: could not open preferences ($e)');
      _prefs = null;
      return;
    }

    final theme = _prefs?.getString(_kTheme);
    if (theme == 'dark') {
      themeNotifier.value = ThemeMode.dark;
    } else if (theme == 'light') {
      themeNotifier.value = ThemeMode.light;
    }

    final locale = _prefs?.getString(_kLocale);
    if (locale != null && locale.isNotEmpty) {
      localeNotifier.value = Locale(locale);
    }

    final notifications = _prefs?.getBool(_kNotifications);
    if (notifications != null) {
      pushNotificationsEnabled.value = notifications;
    }
  }

  static void toggleTheme(bool isDark) {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    _prefs?.setString(_kTheme, isDark ? 'dark' : 'light');
  }

  static void setLocale(String languageCode) {
    localeNotifier.value = Locale(languageCode);
    _prefs?.setString(_kLocale, languageCode);
  }

  static void setNotifications(bool enabled) {
    pushNotificationsEnabled.value = enabled;
    _prefs?.setBool(_kNotifications, enabled);
  }

  static Future<void> clearCache() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    _prefs?.remove(_kNotifications);
    await _prefs?.setBool(_kNotifications, true);
  }
}
