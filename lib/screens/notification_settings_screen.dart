import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

/// Real notification preferences, persisted in SharedPreferences. Replaces the
/// dead "Notifications" settings row.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const _sosKey = 'notif_sos_confirmations';
  static const _maintKey = 'notif_maintenance';
  static const _voiceKey = 'notif_voice_replies';
  static const _tipsKey = 'notif_safety_tips';

  bool _sos = true;
  bool _maintenance = true;
  bool _voice = true;
  bool _tips = false;
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
      _sos = prefs.getBool(_sosKey) ?? true;
      _maintenance = prefs.getBool(_maintKey) ?? true;
      _voice = prefs.getBool(_voiceKey) ?? true;
      _tips = prefs.getBool(_tipsKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.red),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _tile(
                    'SOS confirmations',
                    'Show a notification when an SOS SMS is sent.',
                    _sos,
                    (v) {
                      setState(() => _sos = v);
                      _set(_sosKey, v);
                    },
                  ),
                  _tile(
                    'Maintenance reminders',
                    'Remind me when a car service is due.',
                    _maintenance,
                    (v) {
                      setState(() => _maintenance = v);
                      _set(_maintKey, v);
                    },
                  ),
                  _tile(
                    'Voice replies',
                    'Let the assistant speak its answers out loud.',
                    _voice,
                    (v) {
                      setState(() => _voice = v);
                      _set(_voiceKey, v);
                    },
                  ),
                  _tile(
                    'Safety tips',
                    'Occasional driving-safety tips.',
                    _tips,
                    (v) {
                      setState(() => _tips = v);
                      _set(_tipsKey, v);
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _tile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.red,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
    );
  }
}
