import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A very small hand-rolled localization implementation used by this app.
///
/// Real projects should consider the official Flutter i18n tooling
/// (`flutter_localizations` + `intl` + arb/json files) or a package such as
/// `easy_localization`, but for the purposes of the language selector demo we
/// only need a minimal lookup map.
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // keep the keys simple and only translate the strings actually used in the
  // UI; new entries can be added later as the app grows.
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'language_country': 'Language & Country',
      'select_language': 'Select Language',
      'select_country': 'Select Country',
      'cancel': 'Cancel',
      'save_apply': 'Save & Apply',
      'welcome_back': 'Welcome back, {name} !',
    },
    'ar': {
      'language_country': 'اللغة والدولة',
      'select_language': 'اختر اللغة',
      'select_country': 'اختر الدولة',
      'cancel': 'إلغاء',
      'save_apply': 'حفظ وتطبيق',
      'welcome_back': 'أهلا بعودتك, {name} !',
    },
    'es': {
      'language_country': 'Idioma y país',
      'select_language': 'Seleccionar idioma',
      'select_country': 'Seleccionar país',
      'cancel': 'Cancelar',
      'save_apply': 'Guardar y aplicar',
      'welcome_back': 'Bienvenido de nuevo, {name} !',
    },
    // additional languages can be added here using the same key names
  };

  String translate(String key, [Map<String, String>? params]) {
    final lang = locale.languageCode;
    String? text = _localizedValues[lang]?[key] ??
        _localizedValues['en']?[key]; // fallback to english
    if (text == null) return key;
    if (params != null) {
      params.forEach((k, v) {
        text = text!.replaceAll('{$k}', v);
      });
    }
    return text!;
  }

  static AppLocalizations of(BuildContext context) {
    final loc = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (loc == null) {
      // fallback to English if localization not yet available, avoids null-check crash
      return AppLocalizations(const Locale('en'));
    }
    return loc;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations._localizedValues.keys
        .contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    // using SynchronousFuture because our lookups are synchronous
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
