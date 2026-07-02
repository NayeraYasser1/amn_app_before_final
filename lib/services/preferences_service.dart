import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// A thin wrapper around [SharedPreferences] for persisting the chosen locale.
class PreferencesService {
  static const String _kLanguageCode = 'language_code';
  static const String _kCountryCode = 'country_code';

  Future<Locale?> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_kLanguageCode);
    final countryCode = prefs.getString(_kCountryCode);
    if (languageCode == null) return null;
    return Locale(languageCode, countryCode);
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguageCode, locale.languageCode);
    if (locale.countryCode != null) {
      await prefs.setString(_kCountryCode, locale.countryCode!);
    }
  }
}
