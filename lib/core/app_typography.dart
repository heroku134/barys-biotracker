import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Precision Biometric Typography (Whoop 5.0 / Oura Athletic / Swiss Poster)
/// Strict rules:
/// 1) Geometric grotesk with true tabular figures for big hero numbers
/// 2) Monospace for small uppercase data labels and metric units
/// 3) Plain grotesk for body copy and coaching text
/// ONLY TWO weights total across the entire app:
/// - FontWeight.w400 (regular)
/// - FontWeight.w600 (semibold)
/// Zero walls of w800/w900 bold.
class AppTypography {
  // --- Font Family Fallbacks ---
  static const List<String> _geometricFallbacks = [
    'SF Pro Display',
    'Inter',
    '-apple-system',
    'Roboto',
    'sans-serif',
  ];

  static const List<String> _monoFallbacks = [
    'SF Mono',
    'JetBrains Mono',
    'Roboto Mono',
    'Menlo',
    'Courier New',
    'monospace',
  ];

  static const List<String> _plainFallbacks = [
    'SF Pro Text',
    'Inter',
    '-apple-system',
    'Roboto',
    'sans-serif',
  ];

  /// True tabular figures for jump-free biometric numbers
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  // ===========================================================================
  // ROLE 1: Geometric Grotesk with true tabular figures (Hero numbers, metrics)
  // ===========================================================================

  /// Big hero score (e.g. Recovery 94, Strain 12.4)
  static TextStyle get heroNumber => const TextStyle(
        fontFamilyFallback: _geometricFallbacks,
        fontSize: 54,
        fontWeight: FontWeight.w600, // strictly w600
        letterSpacing: -1.5,
        height: 1.0,
        color: AppColors.textNearWhite,
        fontFeatures: tabularFigures,
      );

  /// Medium hero number (e.g. Heart Rate 72, Sleep 7h 48m)
  static TextStyle get heroNumberMedium => const TextStyle(
        fontFamilyFallback: _geometricFallbacks,
        fontSize: 32,
        fontWeight: FontWeight.w600, // strictly w600
        letterSpacing: -0.8,
        height: 1.05,
        color: AppColors.textNearWhite,
        fontFeatures: tabularFigures,
      );

  /// Compact metric value (e.g. 64 ms, 52 bpm, +0.2°C)
  static TextStyle get metricValue => const TextStyle(
        fontFamilyFallback: _geometricFallbacks,
        fontSize: 16,
        fontWeight: FontWeight.w600, // strictly w600
        letterSpacing: -0.3,
        color: AppColors.textNearWhite,
        fontFeatures: tabularFigures,
      );

  // ===========================================================================
  // ROLE 2: Monospace for small uppercase data labels and metric units
  // ===========================================================================

  /// Uppercase section and card header label (e.g. RECOVERY, DAY STRAIN)
  static TextStyle get monoLabel => const TextStyle(
        fontFamilyFallback: _monoFallbacks,
        fontSize: 11,
        fontWeight: FontWeight.w600, // strictly w600
        letterSpacing: 1.5,
        color: AppColors.textSecondary,
      );

  /// Small uppercase metric unit (e.g. BPM, MS, CAL, / 21.0)
  static TextStyle get monoUnit => const TextStyle(
        fontFamilyFallback: _monoFallbacks,
        fontSize: 10,
        fontWeight: FontWeight.w400, // strictly w400
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      );

  /// Tiny badge / indicator label (e.g. OPTIMAL, TARGET 10.5 — 13.8)
  static TextStyle get monoBadge => const TextStyle(
        fontFamilyFallback: _monoFallbacks,
        fontSize: 9.5,
        fontWeight: FontWeight.w600, // strictly w600
        letterSpacing: 1.4,
      );

  // ===========================================================================
  // ROLE 3: Plain Grotesk for body copy and coaching text
  // ===========================================================================

  /// Coaching insight body text (athletic, crisp, Swiss clarity)
  static TextStyle get body => const TextStyle(
        fontFamilyFallback: _plainFallbacks,
        fontSize: 13.5,
        fontWeight: FontWeight.w400, // strictly w400
        height: 1.45,
        letterSpacing: -0.1,
        color: AppColors.textNearWhite,
      );

  /// Coaching bold emphasis / lead-in
  static TextStyle get bodySemibold => const TextStyle(
        fontFamilyFallback: _plainFallbacks,
        fontSize: 13.5,
        fontWeight: FontWeight.w600, // strictly w600
        height: 1.45,
        letterSpacing: -0.1,
        color: AppColors.textNearWhite,
      );

  /// Secondary descriptive text
  static TextStyle get bodyMuted => const TextStyle(
        fontFamilyFallback: _plainFallbacks,
        fontSize: 12,
        fontWeight: FontWeight.w400, // strictly w400
        height: 1.4,
        color: AppColors.textSecondary,
      );

  /// Plain caption / metadata
  static TextStyle get caption => const TextStyle(
        fontFamilyFallback: _plainFallbacks,
        fontSize: 10.5,
        fontWeight: FontWeight.w400, // strictly w400
        color: AppColors.textMuted,
      );

  // ===========================================================================
  // Backward-compatibility getters (Mapped strictly to w400 / w600)
  // ===========================================================================
  static TextStyle get displayHero => heroNumber;
  static TextStyle get metricLarge => heroNumberMedium;
  static TextStyle get metricMedium => metricValue;
  static TextStyle get screenTitle => const TextStyle(
        fontFamilyFallback: _geometricFallbacks,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: AppColors.textNearWhite,
      );
  static TextStyle get cardTitle => monoLabel;
  static TextStyle get overline => monoLabel;
  static TextStyle get badge => monoBadge;
  static TextStyle get buttonLabel => monoLabel;
}
