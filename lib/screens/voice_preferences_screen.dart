import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

/// Voice assistant preferences: how fast the assistant speaks. Persisted under
/// [rateKey] and read by the voice assistant on start. Replaces the dead
/// "Voice Type" / "Voice Command Sensitivity" rows.
class VoicePreferencesScreen extends StatefulWidget {
  /// Prefs key shared with the voice assistant so a change takes effect there.
  static const String rateKey = 'voice_speech_rate';

  const VoicePreferencesScreen({super.key});

  @override
  State<VoicePreferencesScreen> createState() => _VoicePreferencesScreenState();
}

class _VoicePreferencesScreenState extends State<VoicePreferencesScreen> {
  static const double _defaultRate = 0.48;
  final FlutterTts _tts = FlutterTts();
  double _rate = _defaultRate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _rate = prefs.getDouble(VoicePreferencesScreen.rateKey) ?? _defaultRate;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(VoicePreferencesScreen.rateKey, _rate);
  }

  Future<void> _test() async {
    try {
      await _tts.stop();
      await _tts.setSpeechRate(_rate).timeout(const Duration(seconds: 3));
      await _tts.speak('This is how the AMN assistant will speak.');
    } catch (_) {}
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  String get _rateLabel {
    if (_rate <= 0.38) return 'Slow';
    if (_rate >= 0.58) return 'Fast';
    return 'Normal';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Voice Preferences',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Speaking speed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'How fast the assistant reads its replies aloud — currently '
                    '$_rateLabel.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Slow',
                          style: TextStyle(color: AppColors.muted, fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _rate,
                          min: 0.30,
                          max: 0.70,
                          divisions: 8,
                          activeColor: Colors.white,
                          inactiveColor: Colors.white24,
                          thumbColor: Colors.white,
                          label: _rateLabel,
                          onChanged: (v) => setState(() => _rate = v),
                          onChangeEnd: (_) => _save(),
                        ),
                      ),
                      const Text('Fast',
                          style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _test,
                      icon: const Icon(Icons.volume_up, size: 18),
                      label: const Text('Test voice'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppColors.card,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'The voice itself (language and accent) is provided by your '
                    'device\'s text-to-speech engine. You can change it in the '
                    'system settings under Text-to-speech.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
