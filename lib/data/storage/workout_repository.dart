import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/workout_session.dart';
class WorkoutRepository {
  static const String _keyWorkouts = 'kalkan_workouts_history_v1';
  static const String _legacyKeyWorkouts = 'circa_workouts_history_v1';

  static Future<List<CompletedWorkout>> loadWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    final listJson = prefs.getStringList(_keyWorkouts) ?? prefs.getStringList(_legacyKeyWorkouts);
    if (listJson != null && listJson.isNotEmpty) {
      try {
        return listJson
            .map((s) => CompletedWorkout.fromJson(jsonDecode(s) as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<void> saveWorkout(CompletedWorkout workout) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadWorkouts();
    list.insert(0, workout);
    final rawList = list.map((w) => jsonEncode(w.toJson())).toList();
    await prefs.setStringList(_keyWorkouts, rawList);
  }
}
