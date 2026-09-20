import 'dart:math' as math;
import '../models/readiness.dart';

/// Модель отдельной тренировки (включая автодетектированные)
class WorkoutActivity {
  final String id;
  final String title;
  final DateTime timestamp;
  final int durationMinutes;
  final int avgHeartRate;
  final int maxHeartRate;
  final double activityStrain; // Локальный Strain тренировки (0..21)
  final int caloriesBurned;
  final bool isAutoDetected;

  const WorkoutActivity({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.durationMinutes,
    required this.avgHeartRate,
    required this.maxHeartRate,
    required this.activityStrain,
    required this.caloriesBurned,
    this.isAutoDetected = false,
  });
}

/// Результат расчета нагрузки Strain
class StrainCalculationResult {
  /// Текущий накопленный суточный Strain (0.0 .. 21.0)
  final double currentStrain;

  /// Нижняя граница целевого бюджета нагрузки на сегодня
  final double targetStrainMin;

  /// Верхняя граница целевого бюджета
  final double targetStrainMax;

  /// Статус нагрузки
  final String budgetStatusText;

  /// Остаток до целевого бюджета (положительное = сколько осталось, отрицательное = перегруз)
  final double remainingToTarget;

  /// Находится ли пользователь в оптимальном коридоре
  final bool isInTargetZone;

  /// Минуты в каждой из 5 пульсовых зон
  final List<int> zoneMinutes;

  /// Список тренировок за день
  final List<WorkoutActivity> dailyActivities;

  const StrainCalculationResult({
    required this.currentStrain,
    required this.targetStrainMin,
    required this.targetStrainMax,
    required this.budgetStatusText,
    required this.remainingToTarget,
    required this.isInTargetZone,
    required this.zoneMinutes,
    required this.dailyActivities,
  });
}

class StrainEngine {
  static const double _trimpK = 0.00285;

  /// Расчет накопленного суточного Strain по модели Whoop TRIMP (0.0 — 21.0)
  static double calculateStrainFromZones(List<int> zoneMinutes) {
    if (zoneMinutes.isEmpty) return 0.0;

    // Веса зон пульса
    const weights = [1.0, 2.0, 4.0, 8.0, 16.0];
    var totalTrimp = 0.0;

    for (var i = 0; i < math.min(zoneMinutes.length, weights.length); i++) {
      totalTrimp += zoneMinutes[i] * weights[i];
    }

    // Логарифмическое сжатие в шкалу 0..21
    final strain = 21.0 * (1.0 - math.exp(-_trimpK * totalTrimp));
    return double.parse(strain.toStringAsFixed(1));
  }

  /// Расчет локального Strain за отдельную сессию тренировки
  static double calculateWorkoutStrain({
    required double durationMinutes,
    required int avgHeartRate,
    String sportType = 'run_outdoor',
  }) {
    final intensityFactor = ((avgHeartRate - 60) / 130.0).clamp(0.2, 1.8);
    final rawTrimp = durationMinutes * intensityFactor * 10.0;
    final strain = 21.0 * (1.0 - math.exp(-_trimpK * rawTrimp));
    return double.parse(strain.clamp(1.0, 20.5).toStringAsFixed(1));
  }

  /// Полный расчет дневного бюджета и остатка до целевой зоны
  static StrainCalculationResult evaluate({
    required double currentStrain,
    required RecoveryZone recoveryZone,
    List<int> zoneMinutes = const [75, 45, 20, 8, 2],
    List<WorkoutActivity>? activities,
  }) {
    final double targetMin;
    final double targetMax;

    switch (recoveryZone) {
      case RecoveryZone.optimal:
        targetMin = 14.0;
        targetMax = 18.0;
        break;
      case RecoveryZone.moderate:
        targetMin = 10.0;
        targetMax = 13.9;
        break;
      case RecoveryZone.recovery:
        targetMin = 0.0;
        targetMax = 9.9;
        break;
    }

    final remaining = targetMin - currentStrain;
    final bool inTarget = currentStrain >= targetMin && currentStrain <= targetMax;

    final String statusText;
    if (currentStrain < targetMin) {
      final diff = (targetMin - currentStrain).toStringAsFixed(1);
      statusText = 'Осталось $diff до оптимальной зоны';
    } else if (currentStrain <= targetMax) {
      statusText = 'В оптимальном тренировочном бюджете';
    } else {
      final over = (currentStrain - targetMax).toStringAsFixed(1);
      statusText = 'Превышение бюджета на +$over (зона риска перетрена)';
    }

    final defaultActivities = activities ??
        [
          WorkoutActivity(
            id: 'act_1',
            title: 'Аэробный кросс / Зона 2',
            timestamp: DateTime.now().subtract(const Duration(hours: 5)),
            durationMinutes: 38,
            avgHeartRate: 142,
            maxHeartRate: 164,
            activityStrain: 10.2,
            caloriesBurned: 340,
            isAutoDetected: true,
          ),
        ];

    return StrainCalculationResult(
      currentStrain: currentStrain,
      targetStrainMin: targetMin,
      targetStrainMax: targetMax,
      budgetStatusText: statusText,
      remainingToTarget: remaining,
      isInTargetZone: inTarget,
      zoneMinutes: zoneMinutes,
      dailyActivities: defaultActivities,
    );
  }
}
