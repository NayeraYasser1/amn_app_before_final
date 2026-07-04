import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app ships a single dark theme (chosen for night driving). This screen
/// makes that explicit instead of the old dead "Theme" row.
class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Theme',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _option(
              icon: Icons.dark_mode,
              label: 'Dark',
              subtitle: 'Easy on the eyes while driving at night.',
              selected: true,
            ),
            _option(
              icon: Icons.light_mode,
              label: 'Light',
              subtitle: 'Not available yet.',
              selected: false,
              enabled: false,
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'AMN uses a dark theme throughout so the screen stays readable '
                'and low-glare on the road.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool selected,
    bool enabled = true,
  }) {
    final fg = enabled ? Colors.white : Colors.white38;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.red : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: fg),
        title: Text(label, style: TextStyle(color: fg, fontSize: 15)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppColors.red)
            : null,
      ),
    );
  }
}
