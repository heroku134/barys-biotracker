import 'package:shared_preferences/shared_preferences.dart';

enum ReminderKind { morning, evening }

class ReminderService {
  static const _morningShown = 'kalkan_reminder_morning_';
  static const _eveningShown = 'kalkan_reminder_evening_';

  static String _day([DateTime? d]) {
    final n = d ?? DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  static ReminderKind? activeBanner([DateTime? now]) {
    final n = now ?? DateTime.now();
    if (n.hour >= 5 && n.hour < 11) return ReminderKind.morning;
    if (n.hour >= 21) return ReminderKind.evening;
    return null;
  }

  static Future<bool> shouldShow(ReminderKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    final key = kind == ReminderKind.morning ? '$_morningShown${_day()}' : '$_eveningShown${_day()}';
    return !(prefs.getBool(key) ?? false);
  }

  static Future<void> dismiss(ReminderKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    final key = kind == ReminderKind.morning ? '$_morningShown${_day()}' : '$_eveningShown${_day()}';
    await prefs.setBool(key, true);
  }
}
