import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppIconVariant {
  dark,
  light,
}

class AppIconService {
  static const String _prefKey = 'kalkan_app_icon_variant';
  static const MethodChannel _channel = MethodChannel('sport.kalkan.biotracker/app_icon');

  static final ValueNotifier<AppIconVariant> currentIcon = ValueNotifier<AppIconVariant>(AppIconVariant.dark);

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(_prefKey);
      if (val == 'light') {
        currentIcon.value = AppIconVariant.light;
      } else {
        currentIcon.value = AppIconVariant.dark;
      }
    } catch (_) {}
  }

  static Future<void> setIcon(AppIconVariant variant) async {
    if (currentIcon.value == variant) return;
    currentIcon.value = variant;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, variant == AppIconVariant.light ? 'light' : 'dark');
    } catch (_) {}

    try {
      final iconName = variant == AppIconVariant.light ? 'AppIcon-Light' : null;
      await _channel.invokeMethod('setAlternateIconName', {'name': iconName});
    } catch (e) {
      debugPrint('AppIconService.setIcon note: $e');
    }
  }
}
