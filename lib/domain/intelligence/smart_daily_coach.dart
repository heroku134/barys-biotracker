import '../models/personal_baseline.dart';
import '../models/readiness.dart';
import '../models/telemetry.dart';
import 'readiness_engine.dart';
import 'strain_engine.dart';

enum CoachMode {
  normal,
  proactiveIllnessWarning,
  sustainedFatiguePause, // 3 красных дня подряд: защита ЦНС
  hormoneCycleInsight,
}

class CoachAdvice {
  final String title;
  final String recommendation;
  final String targetStrain;
  final String badgeText;
  final CoachMode mode;
  final bool isPauseModeActive; // Режим болезни / паузы (отключает жесткие квесты)

  const CoachAdvice({
    required this.title,
    required this.recommendation,
    required this.targetStrain,
    required this.badgeText,
    this.mode = CoachMode.normal,
    this.isPauseModeActive = false,
  });
}

class SmartDailyCoach {
  static CoachAdvice generate({
    required BleTelemetry telemetry,
    PersonalBaseline? baseline,
  }) {
    final base = baseline ?? const PersonalBaseline();
    final readiness = ReadinessEngine.calculate(telemetry, baseline: base);
    final strainResult = StrainEngine.evaluate(
      currentStrain: telemetry.currentDayStrain,
      recoveryZone: readiness.zone,
      zoneMinutes: telemetry.zoneMinutes,
    );

    // 1. Проверка на 3 красных дня подряд (Режим Паузы / Восстановления ЦНС)
    final recentScores = base.recentRecoveryScores;
    final is3DaysRed = recentScores.length >= 3 &&
        recentScores.every((score) => score < 34) &&
        readiness.score < 34;

    if (is3DaysRed) {
      return CoachAdvice(
        title: 'Режим защиты ЦНС (Пауза)',
        recommendation:
            'Низкое восстановление фиксируется 3 ночи подряд. Тренировочные квесты временно приостановлены. Организму необходим сон от 9 часов, гидратация и пассивный отдых.',
        targetStrain: 'Целевой Strain: Минимальный (< 6.0)',
        badgeText: 'ЗАЩИТА ЦНС',
        mode: CoachMode.sustainedFatiguePause,
        isPauseModeActive: true,
      );
    }

    // 2. Проактивный Check-in: ранний маркер ОРВИ/воспаления (HRV падает, температура кожи растет)
    final isIllnessRisk = telemetry.hrv < (base.meanHrv * 0.75) && telemetry.skinTempDeviation >= 0.4;
    if (isIllnessRisk) {
      return CoachAdvice(
        title: 'Физиологический стресс / Риск ОРВИ',
        recommendation:
            'ВСР снизилась на ${readiness.hrvDiffPercent}%, а температура кожи поднялась на +${telemetry.skinTempDeviation}°C. Это классический тренд скрытого воспаления или начала инфекции. Ограничьте интенсивность, чтобы иммунная система справилась.',
        targetStrain: 'Целевой Strain: Легкий (< 8.0)',
        badgeText: 'ИММУННЫЙ ЧЕК-ИН',
        mode: CoachMode.proactiveIllnessWarning,
      );
    }

    // 3. Учет гормонального цикла (если указана лютеиновая фаза)
    if (base.cyclePhase == HormoneCyclePhase.luteal) {
      return CoachAdvice(
        title: 'Лютеиновая фаза цикла',
        recommendation:
            'Естественный подъем прогестерона вызывает умеренный рост температуры кожи и снижение ВСР. Это физиологическая норма организма, а не переутомление. Поддерживайте комфортный аэробный темп.',
        targetStrain: 'Целевой бюджет: ${strainResult.targetStrainMin} — ${strainResult.targetStrainMax} Strain',
        badgeText: 'ФАЗА ЦИКЛА',
        mode: CoachMode.hormoneCycleInsight,
      );
    }

    // 4. Стандартный адаптивный коучинг по зонам Recovery
    switch (readiness.zone) {
      case RecoveryZone.optimal:
        return CoachAdvice(
          title: 'Пиковая готовность к нагрузке',
          recommendation:
              'Вегетативная система в идеальном балансе. ${readiness.primaryPositiveFactor}. Рекомендуется использовать день для тяжелых интервалов в Зоне 4-5 или длительного кросса.',
          targetStrain: 'Целевой бюджет: ${strainResult.targetStrainMin} — ${strainResult.targetStrainMax} Strain',
          badgeText: 'ПИКОВАЯ ФОРМА',
        );
      case RecoveryZone.moderate:
        return CoachAdvice(
          title: 'Сбалансированная форма',
          recommendation:
              'Организм стабилен. ${readiness.primaryNegativeFactor}. Отличный день для базовой аэробной работы во 2-й пульсовой зоне и силовой тренировки с контролируемым объемом.',
          targetStrain: 'Целевой бюджет: ${strainResult.targetStrainMin} — ${strainResult.targetStrainMax} Strain',
          badgeText: 'УМЕРЕННО',
        );
      case RecoveryZone.recovery:
        return CoachAdvice(
          title: 'Приоритет восстановления',
          recommendation:
              'Нервная система истощена. ${readiness.primaryNegativeFactor}. Сделайте акцент на растяжке, прогулке, сауне и восстановительном сне.',
          targetStrain: 'Целевой бюджет: < ${strainResult.targetStrainMax} Strain',
          badgeText: 'ДЕНЬ ОТДЫХА',
        );
    }
  }
}
