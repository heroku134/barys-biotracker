import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/workout_session.dart';

class WorkoutRepository {
  static const String _keyWorkouts = 'kalkan_workouts_history_v1';
  static const String _legacyKeyWorkouts = 'circa_workouts_history_v1';

  static String _keyForUser(String? userId) {
    if (userId != null && userId.isNotEmpty) {
      return 'kalkan_workouts_history_${userId}_v1';
    }
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null && currentUid.isNotEmpty) {
        return 'kalkan_workouts_history_${currentUid}_v1';
      }
    } catch (_) {}
    return _keyWorkouts;
  }

  static Future<List<CompletedWorkout>> loadWorkouts({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = _keyForUser(userId);

    List<String>? listJson;
    if (userKey != _keyWorkouts) {
      listJson = prefs.getStringList(userKey);
    } else {
      listJson = prefs.getStringList(_keyWorkouts) ?? prefs.getStringList(_legacyKeyWorkouts);
    }

    if (listJson != null && listJson.isNotEmpty) {
      final parsed = <CompletedWorkout>[];
      for (final s in listJson) {
        try {
          final w = CompletedWorkout.fromJson(jsonDecode(s) as Map<String, dynamic>);
          final id = w.id.toLowerCase();
          final extId = (w.externalId ?? '').toLowerCase();
          if (id.startsWith('mock_') ||
              id.startsWith('ext_mock_') ||
              id.startsWith('ext_test_') ||
              extId.startsWith('mock_') ||
              extId.startsWith('ext_mock_')) {
            continue;
          }
          parsed.add(w);
        } catch (_) {}
      }
      return parsed;
    }
    return [];
  }

  static Future<void> saveWorkout(CompletedWorkout workout, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final userKey = _keyForUser(userId);
    final list = await loadWorkouts(userId: userId);
    list.insert(0, workout);
    final rawList = list.map((w) => jsonEncode(w.toJson())).toList();
    await prefs.setStringList(userKey, rawList);
    if (userKey != _keyWorkouts) {
      // Также очищаем устаревший глобальный ключ, чтобы старые сессии не всплывали
      await prefs.remove(_keyWorkouts);
      await prefs.remove(_legacyKeyWorkouts);
    }
  }

  static Future<void> clearWorkouts({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyWorkouts);
    await prefs.remove(_legacyKeyWorkouts);
    if (userId != null && userId.isNotEmpty) {
      await prefs.remove('kalkan_workouts_history_${userId}_v1');
    }
    for (final k in prefs.getKeys()) {
      if (k.startsWith('kalkan_workouts_history_') || k.startsWith('circa_workouts_history_')) {
        await prefs.remove(k);
      }
    }
  }

  /// Суммарные секунды в 5 пульсовых зонах за текущую неделю (с понедельника)
  static List<int> weeklyZoneSecondsFrom(List<CompletedWorkout> workouts, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final weekStart = n.subtract(Duration(days: n.weekday - 1));
    final from = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final sums = [0, 0, 0, 0, 0];
    for (final w in workouts) {
      if (w.startedAt.isBefore(from)) continue;
      final z = w.hrZoneSeconds;
      for (var i = 0; i < 5 && i < z.length; i++) {
        sums[i] += z[i];
      }
    }
    return sums;
  }

  static Future<List<int>> weeklyZoneSeconds({DateTime? now}) async {
    final workouts = await loadWorkouts();
    return weeklyZoneSecondsFrom(workouts, now: now);
  }
}
