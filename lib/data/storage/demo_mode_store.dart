import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DemoModeStore {
  static const _key = 'kalkan_demo_mode_v1';
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_key)) {
        enabled.value = prefs.getBool(_key) ?? true;
      }
    } catch (_) {}
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {}
  }
}
