import 'package:flutter/material.dart';

/// The app's dark palette, defined once. Previously these colors were
/// re-declared as top-level `const` values in ~9 screen files and had drifted
/// apart (e.g. two slightly different greens and three different borders).
/// Centralizing them fixes the drift and makes a theme change a single edit.
class AppColors {
  const AppColors._();

  static const Color background = Color(0xFF020607);
  static const Color card = Color(0xFF121417);
  static const Color cardRaised = Color(0xFF17191D);
  static const Color field = Color(0xFF0E1215);
  static const Color border = Color(0xFF2C3136);
  static const Color red = Color(0xFFE81218);
  static const Color green = Color(0xFF39D74A);
  static const Color orange = Color(0xFFFF9E2C);
  static const Color blue = Color(0xFF0F7CFF);
  static const Color purple = Color(0xFFB15CFF);
  static const Color yellow = Color(0xFFFFC928);
  static const Color muted = Color(0xFFB7BABF);
}
