import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'circa_haptics.dart';

/// Поддерживаемые языки приложения CIRCA
enum AppLanguage {
  russian(code: 'ru', title: 'Русский', shortTitle: 'RU', flag: '🇷🇺'),
  kyrgyz(code: 'ky', title: 'Кыргызча', shortTitle: 'KG', flag: '🇰🇬'),
  english(code: 'en', title: 'English', shortTitle: 'EN', flag: '🇬🇧');

  final String code;
  final String title;
  final String shortTitle;
  final String flag;

  const AppLanguage({
    required this.code,
    required this.title,
    required this.shortTitle,
    required this.flag,
  });

  static AppLanguage fromCode(String? code) {
    if (code == 'ky') return AppLanguage.kyrgyz;
    if (code == 'en') return AppLanguage.english;
    return AppLanguage.russian;
  }
}

/// Глобальный реактивный менеджер языка приложения
class AppLocaleNotifier extends ValueNotifier<AppLanguage> {
  static const String _prefKey = 'circa_app_language_code';

  AppLocaleNotifier._() : super(AppLanguage.russian);

  static final AppLocaleNotifier instance = AppLocaleNotifier._();

  static AppLanguage get current => instance.value;
  static bool get isKyrgyz => instance.value == AppLanguage.kyrgyz;
  static bool get isRussian => instance.value == AppLanguage.russian;
  static bool get isEnglish => instance.value == AppLanguage.english;

  static String pick(String ru, String ky, [String? en]) {
    switch (instance.value) {
      case AppLanguage.kyrgyz:
        return ky;
      case AppLanguage.english:
        return en ?? ru;
      case AppLanguage.russian:
        return ru;
    }
  }

  /// Инициализация сохраненного языка при старте приложения
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey);
      if (code != null) {
        instance.value = AppLanguage.fromCode(code);
      }
    } catch (_) {}
  }

  /// Переключение языка интерфейса с сохранением и виброоткликом
  static Future<void> setLanguage(AppLanguage language) async {
    if (instance.value == language) return;
    instance.value = language;
    CircaHaptics.selectionClick();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language.code);
    } catch (_) {}
  }

  /// Быстрое переключение между русским и кыргызским
  static Future<void> toggleLanguage() async {
    final next = instance.value == AppLanguage.russian
        ? AppLanguage.kyrgyz
        : AppLanguage.russian;
    await setLanguage(next);
  }
}
