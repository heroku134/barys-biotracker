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
      try {
        final parsed = listJson
            .map((s) => CompletedWorkout.fromJson(jsonDecode(s) as Map<String, dynamic>))
            .where((w) {
              // Автоматическая фильтрация тестовых или устаревших фиктивных сессий
              final id = w.id.toLowerCase();
              final extId = (w.externalId ?? '').toLowerCase();
              if (id.startsWith('ext_strava_') ||
                  id.startsWith('hk_strava_') ||
                  id.startsWith('ext_test_') ||
                  extId.startsWith('hk_strava_') ||
                  extId.startsWith('ext_strava_')) {
                return false;
              }
              return true;
            })
            .toList();
        return parsed;
      } catch (_) {}
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
}
