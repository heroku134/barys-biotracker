import 'package:shared_preferences/shared_preferences.dart';

/// Лёгкий outbox для облачной синхронизации: фиксирует типы «грязных» пушей,
/// которые нужно повторить при следующей возможности (вход, периодический тик).
/// Отдельный модуль, чтобы избежать циклических импортов cloud_sync ↔ session.
class CloudOutbox {
  static const String _key = 'kalkan_cloud_outbox_v1';

  static const String profile = 'profile';
  static const String day = 'day';
  static const String cycle = 'cycle';

  static Future<void> markDirty(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? [];
      if (!list.contains(type)) list.add(type);
      await prefs.setStringList(_key, list);
    } catch (_) {}
  }

  static Future<void> markClean(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? [];
      list.remove(type);
      await prefs.setStringList(_key, list);
    } catch (_) {}
  }

  static Future<List<String>> pending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearOutbox() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}