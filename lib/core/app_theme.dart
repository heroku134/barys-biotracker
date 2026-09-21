import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
import 'circa_haptics.dart';

class AppThemeNotifier extends ValueNotifier<ThemeMode> {
  static const String _prefKey = 'circa_app_theme_mode';

  AppThemeNotifier._() : super(ThemeMode.dark);

  static final AppThemeNotifier instance = AppThemeNotifier._();

  static ThemeMode get current => instance.value;
  static bool get isDark => instance.value == ThemeMode.dark;
  static bool get isLight => instance.value == ThemeMode.light;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_prefKey);
      instance.value = modeStr == 'light' ? ThemeMode.light : ThemeMode.dark;
      AppColors.light = instance.value == ThemeMode.light;
      applySystemUi(instance.value);
    } catch (_) {}
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    if (instance.value == mode) return;
    instance.value = mode;
    AppColors.light = mode == ThemeMode.light;
    applySystemUi(mode);
    CircaHaptics.selectionClick();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }

  static Future<void> toggleTheme() async {
    await setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  static void applySystemUi(ThemeMode mode) {
    final light = mode == ThemeMode.light;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: light ? KalkanColors.light.bg : KalkanColors.dark.bg,
        systemNavigationBarIconBrightness: light ? Brightness.dark : Brightness.light,
      ),
    );
  }

  static ThemeData get darkTheme => _build(KalkanColors.dark, Brightness.dark);
  static ThemeData get lightTheme => _build(KalkanColors.light, Brightness.light);

  static ThemeData _build(KalkanColors palette, Brightness brightness) {
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: palette.bg,
      primaryColor: AppColors.sage,
      cardColor: palette.surface,
      dividerColor: palette.hairline,
      fontFamily: 'Manrope',
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.sage,
        onPrimary: Colors.white,
        secondary: AppColors.amber,
        onSecondary: Colors.white,
        error: AppColors.rose,
        onError: Colors.white,
        surface: palette.surface,
        onSurface: palette.fg,
      ),
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        foregroundColor: palette.fg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: palette.fg,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'Manrope',
        bodyColor: palette.fg,
        displayColor: palette.fg,
      ),
    );
  }
}
