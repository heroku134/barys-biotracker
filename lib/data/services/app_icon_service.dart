import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppIconService {
  static const _channel = MethodChannel('sport.kalkan.biotracker/icon');
  static const _pref = 'kalkan_app_icon_v1';

  static Future<String> current() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pref) ?? 'obsidian';
  }

  static Future<void> setIcon(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pref, id);
    try {
      await _channel.invokeMethod('setIcon', {'name': id == 'porcelain' ? 'Porcelain' : null});
    } catch (_) {}
  }
}
