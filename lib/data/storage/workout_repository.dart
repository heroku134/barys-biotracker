import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/workout_session.dart';

class WorkoutRepository {
  static const String _keyWorkouts = 'circa_workouts_history_v1';

  static Future<List<CompletedWorkout>> loadWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    final listJson = prefs.getStringList(_keyWorkouts);
    if (listJson != null && listJson.isNotEmpty) {
      try {
        return listJson
            .map((s) => CompletedWorkout.fromJson(jsonDecode(s) as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    // Дефолтные тренировки для демонстрации
    return _getDefaultWorkouts();
  }

  static Future<void> saveWorkout(CompletedWorkout workout) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadWorkouts();
    list.insert(0, workout);
    final rawList = list.map((w) => jsonEncode(w.toJson())).toList();
    await prefs.setStringList(_keyWorkouts, rawList);
  }

  static List<CompletedWorkout> _getDefaultWorkouts() {
    final now = DateTime.now();
    return [
      CompletedWorkout(
        id: 'w_01',
        sport: SportType.runOutdoor,
        startedAt: now.subtract(const Duration(hours: 4)),
        durationSeconds: 2320, // 38 мин 40 сек
        calories: 340,
        distanceKm: 5.4,
        avgHr: 142,
        maxHr: 168,
        strain: 10.2,
        xpEarned: 298,
      ),
      CompletedWorkout(
        id: 'w_02',
        sport: SportType.strength,
        startedAt: now.subtract(const Duration(days: 1, hours: 2)),
        durationSeconds: 3100, // 51 мин
        calories: 285,
        distanceKm: 0.0,
        avgHr: 118,
        maxHr: 154,
        strain: 8.4,
        xpEarned: 245,
      ),
      CompletedWorkout(
        id: 'w_03',
        sport: SportType.hiit,
        startedAt: now.subtract(const Duration(days: 2, hours: 5)),
        durationSeconds: 1500, // 25 мин
        calories: 310,
        distanceKm: 0.0,
        avgHr: 158,
        maxHr: 182,
        strain: 12.0,
        xpEarned: 420,
      ),
    ];
  }
}
