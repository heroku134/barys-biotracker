import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/workout_session.dart';
import 'demo_mode_store.dart';

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
    if (DemoModeStore.enabled.value) return _getDefaultWorkouts();
    return [];
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
        routeCoordinates: const [
          [43.238949, 76.889709],
          [43.239320, 76.890450],
          [43.239980, 76.891620],
          [43.241150, 76.893120],
          [43.242310, 76.894450],
          [43.243540, 76.895820],
          [43.244780, 76.897100],
          [43.245910, 76.898430],
          [43.246820, 76.899200],
          [43.247500, 76.898120],
          [43.246910, 76.896500],
          [43.245820, 76.894900],
          [43.244400, 76.893200],
          [43.243100, 76.891800],
          [43.241900, 76.890600],
          [43.240500, 76.889900],
          [43.239100, 76.889650],
        ],
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
