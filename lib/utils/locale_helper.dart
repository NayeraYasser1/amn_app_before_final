import 'package:flutter/material.dart';

/// Helpers for converting between the human-readable language names used in the
/// UI and the canonical [Locale] objects that the [MaterialApp] understands.

Locale localeFromLanguage(String language) {
  switch (language) {
    case 'English':
      return const Locale('en');
    case 'Italian':
      return const Locale('it');
    case 'Chinese':
      return const Locale('zh');
    case 'French':
      return const Locale('fr');
    case 'German':
      return const Locale('de');
    case 'Spanish':
      return const Locale('es');
    case 'Russian':
      return const Locale('ru');
    case 'Arabic':
      return const Locale('ar');
    case 'Hindi':
      return const Locale('hi');
    case 'Portuguese':
      return const Locale('pt');
    default:
      return const Locale('en');
  }
}

String languageCodeFromLocale(Locale locale) => locale.languageCode;

String languageFromLocale(Locale locale) {
  switch (locale.languageCode) {
    case 'en':
      return 'English';
    case 'it':
      return 'Italian';
    case 'zh':
      return 'Chinese';
    case 'fr':
      return 'French';
    case 'de':
      return 'German';
    case 'es':
      return 'Spanish';
    case 'ru':
      return 'Russian';
    case 'ar':
      return 'Arabic';
    case 'hi':
      return 'Hindi';
    case 'pt':
      return 'Portuguese';
    default:
      return 'English';
  }
}
