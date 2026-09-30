import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Семантические роли цвета текста, одинаково понятные в тёмной и светлой темах.
enum AppTypographyColor {
  primary,
  secondary,
  muted,
  none;

  /// Устаревший алиас для обратной совместимости
  static const AppTypographyColor nearWhite = AppTypographyColor.primary;
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
    this.colorKind = AppTypographyColor.primary,
  });

  @override
  Color? get color {
    final explicit = super.color;
    if (explicit != null) return explicit;
    switch (colorKind) {
      case AppTypographyColor.primary:
        return AppColors.textPrimary;
      case AppTypographyColor.secondary:
        return AppColors.textSecondary;
      case AppTypographyColor.muted:
        return AppColors.textMuted;
      case AppTypographyColor.none:
        return null;
    }
  }

  /// Позволяет вызывать стиль как функцию с цветом: `AppTypography.screenTitle(palette.fg)`
  AppTextStyle call([Color? color]) => color != null ? copyWith(color: color) : this;

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
    AppTypographyColor? colorKind,
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
      colorKind: colorKind ?? this.colorKind,
    );
  }
}

/// Замороженная шкала типографики КАЛКАН
/// 
/// heroNumber             54  sans  -1.6
/// metricLarge            32  sans  -0.8
/// metricMedium           24  sans  -0.5  (именованное исключение: промежуточная метрика)
/// metric / metricValue   16  sans  -0.3
/// screenTitle            18  sans  -0.3
/// body / bodySemibold    14  sans  -0.1
/// bodyMuted              12.5 sans
/// caption                11  sans
/// monoLabel / overline   11  mono  +1.4
/// monoUnit               10  mono  +1.1
/// monoBadge              9.5 mono  +1.3  (именованное исключение: микробэдж)
class AppTypography {
  static const String sans = 'Manrope';
  static const String mono = 'IBM Plex Mono';

  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  // 1. Hero 54 — главный жест приложения (восстановление, напряжение)
  static const AppTextStyle heroNumber = AppTextStyle(
    fontFamily: sans,
    fontSize: 54,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.6,
    height: 1.0,
    colorKind: AppTypographyColor.primary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // 2. Метрики (16 - 32)
  static const AppTextStyle metricLarge = AppTextStyle(
    fontFamily: sans,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.05,
    colorKind: AppTypographyColor.primary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const AppTextStyle heroNumberMedium = metricLarge;

  /// Именованное исключение: средний размер цифры (пульс в карточках)
  static const AppTextStyle metricMedium = AppTextStyle(
    fontFamily: sans,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    colorKind: AppTypographyColor.primary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const AppTextStyle metric = AppTextStyle(
    fontFamily: sans,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    colorKind: AppTypographyColor.primary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const AppTextStyle metricValue = metric;

  // 3. Заголовки экранов и модалок: 18 semibold
  static const AppTextStyle screenTitle = AppTextStyle(
    fontFamily: sans,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    colorKind: AppTypographyColor.primary,
  );

  // 4. Основной текст: 14 w400 / w600
  static const AppTextStyle body = AppTextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: -0.1,
    colorKind: AppTypographyColor.primary,
  );

  static const AppTextStyle bodySemibold = AppTextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.45,
    letterSpacing: -0.1,
    colorKind: AppTypographyColor.primary,
  );

  // 5. Вторичный текст: 12.5
  static const AppTextStyle bodyMuted = AppTextStyle(
    fontFamily: sans,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.4,
    colorKind: AppTypographyColor.secondary,
  );

  // 6. Подписи и подсказки: 11 sans
  static const AppTextStyle caption = AppTextStyle(
    fontFamily: sans,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    colorKind: AppTypographyColor.muted,
  );

  // 7. Моноширинные приборные метки: 11 mono +1.4
  static const AppTextStyle monoLabel = AppTextStyle(
    fontFamily: mono,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    colorKind: AppTypographyColor.secondary,
  );

  static const AppTextStyle overline = monoLabel;
  static const AppTextStyle eyebrow = monoLabel;

  // 8. Единицы измерения: 10 mono +1.1
  static const AppTextStyle monoUnit = AppTextStyle(
    fontFamily: mono,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.1,
    colorKind: AppTypographyColor.secondary,
  );

  /// Именованное исключение: микро-бэдж (теги статуса, миниатюрные индикаторы)
  static const AppTextStyle monoBadge = AppTextStyle(
    fontFamily: mono,
    fontSize: 9.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.3,
    colorKind: AppTypographyColor.none,
  );

  // Вспомогательные методы
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
  static AppTextStyle get cardTitle => monoLabel;
  static AppTextStyle get badge => monoBadge;
  static AppTextStyle get buttonLabel => bodySemibold;
}
