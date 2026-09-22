import 'package:flutter/material.dart';
import 'app_colors.dart';

enum AppTypographyColor {
  nearWhite,
  secondary,
  muted,
  none,
}

class AppTextStyle extends TextStyle {
  final AppTypographyColor colorKind;

  const AppTextStyle({
    super.inherit,
    super.color,
    super.backgroundColor,
    super.fontFamily,
    super.fontFamilyFallback,
    super.package,
    super.fontSize,
    super.fontWeight,
    super.fontStyle,
    super.letterSpacing,
    super.wordSpacing,
    super.textBaseline,
    super.height,
    super.leadingDistribution,
    super.locale,
    super.foreground,
    super.background,
    super.shadows,
    super.fontFeatures,
    super.fontVariations,
    super.decoration,
    super.decorationColor,
    super.decorationStyle,
    super.decorationThickness,
    super.debugLabel,
    super.overflow,
    this.colorKind = AppTypographyColor.nearWhite,
  });

  @override
  Color? get color {
    final explicit = super.color;
    if (explicit != null) return explicit;
    switch (colorKind) {
      case AppTypographyColor.nearWhite:
        return AppColors.textNearWhite;
      case AppTypographyColor.secondary:
        return AppColors.textSecondary;
      case AppTypographyColor.muted:
        return AppColors.textMuted;
      case AppTypographyColor.none:
        return null;
    }
  }

  TextStyle call([Color? color]) => color != null ? copyWith(color: color) : this;

  @override
  AppTextStyle copyWith({
    bool? inherit,
    Color? color,
    Color? backgroundColor,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    String? package,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    TextLeadingDistribution? leadingDistribution,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    List<FontVariation>? fontVariations,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    String? debugLabel,
    TextOverflow? overflow,
  }) {
    return AppTextStyle(
      inherit: inherit ?? this.inherit,
      color: color ?? super.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontFamily: fontFamily ?? this.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
      package: package,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      textBaseline: textBaseline ?? this.textBaseline,
      height: height ?? this.height,
      leadingDistribution: leadingDistribution ?? this.leadingDistribution,
      locale: locale ?? this.locale,
      foreground: foreground ?? this.foreground,
      background: background ?? this.background,
      shadows: shadows ?? this.shadows,
      fontFeatures: fontFeatures ?? this.fontFeatures,
      fontVariations: fontVariations ?? this.fontVariations,
      decoration: decoration ?? this.decoration,
      decorationColor: decorationColor ?? this.decorationColor,
      decorationStyle: decorationStyle ?? this.decorationStyle,
      decorationThickness: decorationThickness ?? this.decorationThickness,
      debugLabel: debugLabel ?? this.debugLabel,
      overflow: overflow ?? this.overflow,
      colorKind: colorKind,
    );
  }
}

class AppTypography {
  static const String sans = 'Manrope';
  static const String mono = 'IBM Plex Mono';

  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  static const AppTextStyle heroNumber = AppTextStyle(
    fontFamily: sans,
    fontSize: 54,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.6,
    height: 1.0,
    colorKind: AppTypographyColor.nearWhite,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const AppTextStyle heroNumberMedium = AppTextStyle(
    fontFamily: sans,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.05,
    colorKind: AppTypographyColor.nearWhite,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const AppTextStyle metricValue = AppTextStyle(
    fontFamily: sans,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    colorKind: AppTypographyColor.nearWhite,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const AppTextStyle monoLabel = AppTextStyle(
    fontFamily: mono,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    colorKind: AppTypographyColor.secondary,
  );

  static const AppTextStyle monoUnit = AppTextStyle(
    fontFamily: mono,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.1,
    colorKind: AppTypographyColor.secondary,
  );

  static const AppTextStyle monoBadge = AppTextStyle(
    fontFamily: mono,
    fontSize: 9.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.3,
    colorKind: AppTypographyColor.none,
  );

  static const AppTextStyle body = AppTextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: -0.1,
    colorKind: AppTypographyColor.nearWhite,
  );

  static const AppTextStyle bodySemibold = AppTextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.45,
    letterSpacing: -0.1,
    colorKind: AppTypographyColor.nearWhite,
  );

  static const AppTextStyle bodyMuted = AppTextStyle(
    fontFamily: sans,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.4,
    colorKind: AppTypographyColor.secondary,
  );

  static const AppTextStyle caption = AppTextStyle(
    fontFamily: sans,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    colorKind: AppTypographyColor.muted,
  );

  static const AppTextStyle screenTitle = AppTextStyle(
    fontFamily: sans,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    colorKind: AppTypographyColor.nearWhite,
  );

  static AppTextStyle label([Color? color]) => color != null
      ? caption.copyWith(color: color, fontWeight: FontWeight.w500)
      : const AppTextStyle(
          fontFamily: sans,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          colorKind: AppTypographyColor.muted,
        );

  static AppTextStyle hint([Color? color]) => color != null ? bodyMuted.copyWith(color: color) : bodyMuted;

  static AppTextStyle get displayHero => heroNumber;
  static AppTextStyle get metricLarge => heroNumberMedium;
  static AppTextStyle get metricMedium => metricValue;
  static AppTextStyle get cardTitle => label();
  static AppTextStyle get overline => label();
  static AppTextStyle get badge => caption;
  static AppTextStyle get buttonLabel => bodySemibold;
}
