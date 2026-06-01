import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'openclaw_api.dart';

class AppServices {
  AppServices._();

  static const Locale englishLocale = Locale('en');
  static const Locale vietnameseLocale = Locale('vi');
  static const String _localePrefKey = 'big_luna_locale';

  static OpenClawApi? _api;
  static AppConfig? _config;
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier<Locale>(englishLocale);

  static OpenClawApi get api => _api ??= OpenClawApi(config: config);
  static AppConfig get config => _config ??= AppConfig.fromEnv();

  static Future<void> init() async {
    _config = AppConfig.fromEnv();
    _api = OpenClawApi(config: _config);
    await _loadLocale();
  }

  static Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localePrefKey)?.trim().toLowerCase();
    localeNotifier.value = switch (raw) {
      'vi' => vietnameseLocale,
      _ => englishLocale,
    };
  }

  static Future<void> setLocale(Locale locale) async {
    final normalized = locale.languageCode == 'vi' ? vietnameseLocale : englishLocale;
    localeNotifier.value = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefKey, normalized.languageCode);
  }
}
