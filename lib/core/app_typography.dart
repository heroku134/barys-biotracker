import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Премиальная шрифтовая система KALKAN SPORT (СААТ-1)
/// Вдохновлена швейцарской типографикой (Leica, Bang & Olufsen, Apple Watch Ultra).
/// Обеспечивает строгую иерархию, оптический кернинг и табулярные цифры без дрожания.
class AppTypography {
  // Список шрифтов с приоритетом системных высокоточных шрифтов
  static const List<String> _fontFamilyFallback = [
    'SF Pro Display',
    'SF Pro Text',
    '-apple-system',
    'Roboto',
    'Inter',
    'sans-serif',
  ];

  static const String _primaryFontFamily = 'SF Pro Display';

  /// Табулярные цифры для стабильного отображения биометрических значений (без сдвигов)
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  /// Огромные биометрические показатели (Recovery Score 94, Strain 12.4, Пульс 72)
  static TextStyle get displayHero => const TextStyle(
        fontFamily: _primaryFontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 46,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        height: 1.05,
        color: AppColors.fg,
        fontFeatures: tabularFigures,
      );

  /// Крупные значения в карточках (94%, 118 bpm, +0.35°C)
  static TextStyle get metricLarge => const TextStyle(
        fontFamily: _primaryFontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.1,
        color: AppColors.fg,
        fontFeatures: tabularFigures,
      );

  /// Средние числовые значения (ВСР 64 мс, Сон 7ч 30м)
  static TextStyle get metricMedium => const TextStyle(
        fontFamily: _primaryFontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: AppColors.fg,
        fontFeatures: tabularFigures,
      );

  /// Заголовки экранов первого уровня
  static TextStyle get screenTitle => const TextStyle(
        fontFamily: _primaryFontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: AppColors.fg,
      );

  /// Заголовки карточек и блоков
  static TextStyle get cardTitle => const TextStyle(
        fontFamily: _primaryFontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.fg,
      );

  /// Оверлайны, категории и статусы (капслок с оптическим трекингом)
  static TextStyle get overline => const TextStyle(
        fontFamily: _primaryFontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.8,
        color: AppColors.muted,
      );

  /// Выделенные бейджи
  static TextStyle get badge => const TextStyle(
        fontFamily: _primaryFontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
      );

  /// Основной текст рекомендаций и физиологического анализа
  static TextStyle get body => const TextStyle(
        fontFamily: _primaryFontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.38,
        letterSpacing: -0.1,
        color: AppColors.fg,
      );

  /// Вторичный пояснительный текст
  static TextStyle get bodyMuted => const TextStyle(
        fontFamily: _primaryFontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: AppColors.muted,
      );

  /// Мелкие подписи и единицы измерения
  static TextStyle get caption => const TextStyle(
        fontFamily: _primaryFontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.faint,
      );

  /// Текст кнопок действий
  static TextStyle get buttonLabel => const TextStyle(
        fontFamily: _primaryFontFamily,
        fontFamilyFallback: _fontFamilyFallback,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
      );
}
