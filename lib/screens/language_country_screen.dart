import 'package:flutter/material.dart';
import '../services/usage_logger.dart';
import '../utils/locale_helper.dart';
import '../services/preferences_service.dart';
import '../app_localizations.dart';

class LanguageCountryScreen extends StatefulWidget {
  final String initialLanguage;
  final String initialCountry;

  const LanguageCountryScreen({
    super.key,
    required this.initialLanguage,
    required this.initialCountry,
  });

  @override
  State<LanguageCountryScreen> createState() => _LanguageCountryScreenState();
}

class _LanguageCountryScreenState extends State<LanguageCountryScreen> {
  late String _language;
  late String _country;

  final List<String> _languages = const [
    'English',
    'Italian',
    'Chinese',
    'French',
    'German',
    'Spanish',
    'Russian',
    'Arabic',
    'Hindi',
    'Portuguese',
  ];

  final List<String> _countries = const [
    'Egypt',
    'United States',
    'United Kingdom',
    'France',
    'Germany',
    'Italy',
    'Spain',
    'United Arab Emirates',
    'Saudi Arabia',
    'Canada',
    'Australia',
    'India',
  ];

  final _prefs = PreferencesService();

  @override
  void initState() {
    super.initState();
    _language = widget.initialLanguage;
    _country = widget.initialCountry;
  }

  void _saveAndClose() async {
    try {
      await UsageLogger.logAction('language_country_changed', data: {
        'language': _language,
        'country': _country,
      });
    } catch (_) {
      // Logging failed (possibly offline or not initialized) — still close with values
    }

    // persist locale choice
    final locale = localeFromLanguage(_language);
    await _prefs.setLocale(locale);

    if (!mounted) return;
    Navigator.of(context).pop({'language': _language, 'country': _country});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050415),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(AppLocalizations.of(context).translate('language_country')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context).translate('select_language'), style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _languages.map((lang) {
                final selected = lang == _language;
                return ChoiceChip(
                  label: Text(lang, style: TextStyle(color: selected ? Colors.black : Colors.white)),
                  selected: selected,
                  onSelected: (_) => setState(() => _language = lang),
                  selectedColor: Colors.white,
                  backgroundColor: Colors.grey[800],
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(AppLocalizations.of(context).translate('select_country'), style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _countries.map((c) {
                final selected = c == _country;
                return ChoiceChip(
                  label: Text(c, style: TextStyle(color: selected ? Colors.black : Colors.white)),
                  selected: selected,
                  onSelected: (_) => setState(() => _country = c),
                  selectedColor: Colors.white,
                  backgroundColor: Colors.grey[800],
                );
              }).toList(),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.of(context).translate('cancel'), style: const TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveAndClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(AppLocalizations.of(context).translate('save_apply')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
