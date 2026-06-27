import 'package:flutter/material.dart';

/// Typography built on the bundled **Cairo** Arabic font (see pubspec.yaml).
/// Generous line height keeps long-form Arabic comfortable to read.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Cairo';

  static TextTheme textTheme(ColorScheme scheme) {
    final Color color = scheme.onSurface;
    TextStyle style(double size, FontWeight weight, {double height = 1.3}) =>
        TextStyle(fontFamily: fontFamily, fontSize: size, fontWeight: weight, color: color, height: height);

    return TextTheme(
      displaySmall: style(32, FontWeight.w700),
      headlineMedium: style(26, FontWeight.w700),
      headlineSmall: style(22, FontWeight.w600),
      titleLarge: style(20, FontWeight.w600),
      titleMedium: style(16, FontWeight.w600),
      bodyLarge: style(16, FontWeight.w400, height: 1.6),
      bodyMedium: style(14, FontWeight.w400, height: 1.6),
      labelLarge: style(15, FontWeight.w600),
    );
  }
}
