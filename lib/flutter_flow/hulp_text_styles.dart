import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'hulp_colors.dart';

/// Estilos tipográficos comunes para las pantallas de Talento Hulp.
abstract final class HulpTextStyles {
  static const primary = HulpColors.textPrimary;
  static const secondary = HulpColors.textSecondary;
  static const muted = HulpColors.textMuted;
  static const link = HulpColors.brand;
  static const error = HulpColors.error;

  static TextStyle inter(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w400,
    double height = 1.35,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: 0,
      );

  static TextStyle get header =>
      inter(20, weight: FontWeight.w700, height: 1.2);
  static TextStyle get section =>
      inter(18, weight: FontWeight.w600, height: 1.25);
  static TextStyle get card => inter(15, weight: FontWeight.w600);
  static TextStyle get input => inter(16);
  static TextStyle get body => inter(14);
  static TextStyle get label =>
      inter(14, weight: FontWeight.w500, color: secondary);
  static TextStyle get primaryAction => inter(16, weight: FontWeight.w600);
  static TextStyle get secondaryAction => inter(14, weight: FontWeight.w600);
  static TextStyle get compact => inter(12, weight: FontWeight.w600);
  static TextStyle get help => inter(12, color: muted);
  static TextStyle get fieldError => help.copyWith(color: error);

  static TextTheme get textTheme => TextTheme(
        displayLarge: inter(36, weight: FontWeight.w700),
        displayMedium: inter(28, weight: FontWeight.w700),
        displaySmall: inter(24, weight: FontWeight.w700),
        headlineLarge: header,
        headlineMedium: section,
        headlineSmall: section,
        titleLarge: header,
        titleMedium: input,
        titleSmall: card,
        bodyLarge: input,
        bodyMedium: body,
        bodySmall: help,
        labelLarge: secondaryAction,
        labelMedium: label,
        labelSmall: compact,
      ).apply(bodyColor: primary, displayColor: primary).copyWith(
            bodySmall: help,
            labelMedium: label,
          );
}
