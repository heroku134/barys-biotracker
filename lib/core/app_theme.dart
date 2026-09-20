import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
import 'circa_haptics.dart';

/// Реактивный менеджер темы оформления CIRCA
class AppThemeNotifier extends ValueNotifier<ThemeMode> {
  static const String _prefKey = 'circa_app_theme_mode';

  AppThemeNotifier._() : super(ThemeMode.dark);

  static final AppThemeNotifier instance = AppThemeNotifier._();

  static ThemeMode get current => instance.value;
  static bool get isDark => instance.value == ThemeMode.dark;
  static bool get isLight => instance.value == ThemeMode.light;

  /// Инициализация сохраненной темы при старте
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_prefKey);
      if (modeStr == 'light') {
        instance.value = ThemeMode.light;
      } else {
        instance.value = ThemeMode.dark;
      }
    } catch (_) {}
  }

  /// Установка темы с сохранением и тактильным откликом
  static Future<void> setThemeMode(ThemeMode mode) async {
    if (instance.value == mode) return;
    instance.value = mode;
    CircaHaptics.selectionClick();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }

  /// Быстрое переключение темы
  static Future<void> toggleTheme() async {
    await setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  /// Темная тема (фирменный скандинавский графит CIRCA)
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.stage,
      primaryColor: AppColors.amber,
      cardColor: AppColors.surface,
      dividerColor: AppColors.line,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.amber,
        secondary: AppColors.sage,
        surface: AppColors.surface,
      ),
      fontFamily: 'SF Pro Display',
      fontFamilyFallback: const ['SF Pro Text', '-apple-system', 'Roboto', 'Inter', 'sans-serif'],
    );
  }

  /// Светлая тема (мягкий благородный титановый белый без слепящей белизны)
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF3F5F8),
      primaryColor: AppColors.amber,
      cardColor: Colors.white,
      dividerColor: const Color(0x18000000),
      colorScheme: const ColorScheme.light(
        primary: AppColors.amber,
        secondary: AppColors.sage,
        surface: Colors.white,
      ),
      fontFamily: 'SF Pro Display',
      fontFamilyFallback: const ['SF Pro Text', '-apple-system', 'Roboto', 'Inter', 'sans-serif'],
    );
  }
}
