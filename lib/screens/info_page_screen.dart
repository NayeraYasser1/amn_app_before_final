import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One block of content on an [InfoPageScreen] — an optional heading and a body.
class InfoSection {
  final String? heading;
  final String body;
  const InfoSection(this.body, {this.heading});
}

/// An optional action button rendered under the content (e.g. "Send email").
class InfoAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const InfoAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

/// A reusable, read-only content screen used by the Settings rows that show
/// static information (FAQs, User Guide, Terms & Privacy, About, Contact Us…).
/// Keeps the content out of the screen so one widget serves every info page.
class InfoPageScreen extends StatelessWidget {
  final String title;
  final List<InfoSection> sections;
  final List<InfoAction> actions;

  const InfoPageScreen({
    super.key,
    required this.title,
    required this.sections,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            for (final s in sections) ...[
              if (s.heading != null) ...[
                Text(
                  s.heading!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                s.body,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
            ],
            for (final a in actions) ...[
              const SizedBox(height: 2),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: a.onTap,
                  icon: Icon(a.icon, size: 18),
                  label: Text(a.label),
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
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
