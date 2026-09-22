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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.raised,
        hintStyle: TextStyle(color: palette.muted, fontFamily: 'Manrope'),
        labelStyle: TextStyle(color: palette.secondary, fontFamily: 'Manrope'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.sage),
        ),
      ),
      shadowColor: palette.shadow,
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: brightness == Brightness.light ? 2 : 0,
        shadowColor: palette.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.hairline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        shadowColor: palette.shadow,
        titleTextStyle: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 18, color: palette.fg),
        contentTextStyle: TextStyle(fontFamily: 'Manrope', fontSize: 14, height: 1.45, color: palette.secondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        shadowColor: palette.shadow,
        modalBackgroundColor: palette.surface,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.raised,
        selectedColor: AppColors.sage,
        labelStyle: TextStyle(color: palette.fg, fontFamily: 'Manrope', fontSize: 12),
        secondaryLabelStyle: TextStyle(color: Colors.white, fontFamily: 'Manrope', fontSize: 12),
        side: BorderSide(color: palette.hairline),
      ),
    );
  }
}
