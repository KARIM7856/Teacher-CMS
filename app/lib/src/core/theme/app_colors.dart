import 'package:flutter/material.dart';

/// Brand palette — warm, modern, friendly for learners.
///
/// Most colors are derived from [seed] via `ColorScheme.fromSeed`; the values
/// here are the few brand anchors we set deliberately.
class AppColors {
  AppColors._();

  /// Seed for the Material 3 color scheme — a warm, inviting orange.
  static const Color seed = Color(0xFFF2784B);

  /// Secondary accent (teal) for highlights and positive states.
  static const Color accent = Color(0xFF2A9D8F);

  /// Warm off-white used as the app background.
  static const Color surface = Color(0xFFFFFBF6);
}
