import 'dart:math' as math;
import '../models/personal_baseline.dart';
import '../models/readiness.dart';
import '../models/telemetry.dart';
import 'sleep_engine.dart';

/// ReadinessEngine — Персональная модель восстановления вегетативной нервной системы (Whoop / Oura)
/// Сравнение с личным скользящим профилем за 60 дней.
class ReadinessEngine {
  static ReadinessResult calculate(
    BleTelemetry telemetry, {
    PersonalBaseline? baseline,
  }) {
    final base = baseline ?? const PersonalBaseline();

    // 1. Off-wrist защита: если браслет снят ночью — замер бракуется!
    if (telemetry.isOffWrist) {
      return ReadinessResult(
        score: 0,
        zone: RecoveryZone.recovery,
        hrvFactor: 0,
        rhrFactor: 0,
        sleepFactor: 0,
        rrFactor: 0,
        tempFactor: 0,
        currentHrv: 0,
        baselineHrv: base.meanHrv,
        hrvDiffPercent: -100,
        currentRhr: 0,
        baselineRhr: base.meanRhr,
        rhrDiffBpm: 0,
        currentRr: 0,
        baselineRr: base.meanRespiratoryRate,
        tempDiffCelsius: 0,
        primaryNegativeFactor: 'Браслет был снят с руки ночью',
        primaryPositiveFactor: 'Нет данных',
        isCalibrating: base.isCalibrating,
        calibrationDay: base.calibrationDaysDone,
        isOffWrist: true,
      );
    }

    // 2. Оценка ВСР (rMSSD) относительно личной медианы
    // Если HRV = 64 при базе 64 -> 85-90 баллов. Если HRV 41 -> -36% -> падение до ~52 баллов.
    final hrvRatio = telemetry.hrv / math.max(10.0, base.meanHrv);
    final hrvDiffPercent = (((telemetry.hrv - base.meanHrv) / base.meanHrv) * 100).round();
    final hrvScore = (hrvRatio * 85.0).clamp(10.0, 100.0).round();

    // 3. Оценка ночного пульса покоя (RHR Nadir в глубоком сне)
    // Инвертированная шкала: чем ниже пульс покоя относительно базы, тем выше балл
    final rhrDiffBpm = telemetry.restingHeartRate - base.meanRhr;
    final double rhrNormalized;
    if (rhrDiffBpm <= 0) {
      // Пульс покоя ниже или равен норме — отлично
      rhrNormalized = 95.0 + (-rhrDiffBpm * 2.5).clamp(0.0, 5.0);
    } else {
      // Пульс покоя подскочил — каждый лишний удар снижает балл
      rhrNormalized = 90.0 - (rhrDiffBpm * 7.5);
    }
    final rhrScore = rhrNormalized.clamp(15.0, 100.0).round();

    // 4. Оценка сна из SleepEngine (Длительность vs Need + Эффективность + Consistency + Релаксация)
    final sleepAnalysis = SleepEngine.calculate(telemetry: telemetry, baseline: base);
    final sleepScore = sleepAnalysis.sleepPerformanceScore;

    // 5. Оценка частоты дыхания (RR)
    // Очень стабильный показатель. Отклонение на +1.5..+2.0 вдоха — маркер инфекции или стресса
    final rrDiff = telemetry.respiratoryRate - base.meanRespiratoryRate;
    final double rrNormalized;
    if (rrDiff.abs() <= 0.6) {
      rrNormalized = 98.0;
    } else {
      rrNormalized = 95.0 - (rrDiff.abs() * 25.0);
    }
    final rrScore = rrNormalized.clamp(20.0, 100.0).round();

    // 6. Оценка отклонения температуры кожи (ΔT)
    // Норма |ΔT| <= 0.2°C. Повышение на +0.5..+1.0°C снижает балл
    final tempDiff = telemetry.skinTempDeviation;
    final double tempNormalized;
    if (tempDiff.abs() <= 0.2) {
      tempNormalized = 98.0;
    } else if (tempDiff > 0.2) {
      tempNormalized = 95.0 - ((tempDiff - 0.2) * 60.0);
    } else {
      tempNormalized = 90.0 - ((tempDiff.abs() - 0.2) * 30.0);
    }
    final tempScore = tempNormalized.clamp(15.0, 100.0).round();

    // 7. Единая каноническая формула:
    // Recovery = 0.35·HRV + 0.25·RHR + 0.20·Sleep + 0.10·RR + 0.10·Temp
    // Нагрузка (Strain / шаги) сюда НЕ кладется!
    final rawRecovery = (0.35 * hrvScore) +
        (0.25 * rhrScore) +
        (0.20 * sleepScore) +
        (0.10 * rrScore) +
        (0.10 * tempScore);

    final finalScore = rawRecovery.round().clamp(0, 100);

    final RecoveryZone zone;
    if (finalScore >= 67) {
      zone = RecoveryZone.optimal;
    } else if (finalScore >= 34) {
      zone = RecoveryZone.moderate;
    } else {
      zone = RecoveryZone.recovery;
    }

    // Определение главных драйверов
    final factors = [
      (name: 'ВСР (rMSSD)', score: hrvScore, desc: '$hrvDiffPercent% vs базы'),
      (name: 'Пульс покоя', score: rhrScore, desc: '${rhrDiffBpm >= 0 ? "+$rhrDiffBpm" : "$rhrDiffBpm"} bpm vs базы'),
      (name: 'Качество сна', score: sleepScore, desc: '$sleepScore% от потребности'),
      (name: 'Частота дыхания', score: rrScore, desc: '${telemetry.respiratoryRate.toStringAsFixed(1)} вдохов/мин'),
      (name: 'Температура кожи', score: tempScore, desc: '${tempDiff >= 0 ? "+$tempDiff" : "$tempDiff"}°C'),
    ];

    factors.sort((a, b) => a.score.compareTo(b.score));
    final primaryNegative = '${factors.first.name} (${factors.first.desc}) — главный сдерживающий фактор';
    final primaryPositive = '${factors.last.name} (${factors.last.desc}) — ключевой драйвер восстановления';

    return ReadinessResult(
      score: finalScore,
      zone: zone,
      hrvFactor: hrvScore,
      rhrFactor: rhrScore,
      sleepFactor: sleepScore,
      rrFactor: rrScore,
      tempFactor: tempScore,
      currentHrv: telemetry.hrv,
      baselineHrv: base.meanHrv,
      hrvDiffPercent: hrvDiffPercent,
      currentRhr: telemetry.restingHeartRate,
      baselineRhr: base.meanRhr,
      rhrDiffBpm: rhrDiffBpm,
      currentRr: telemetry.respiratoryRate,
      baselineRr: base.meanRespiratoryRate,
      tempDiffCelsius: tempDiff,
      primaryNegativeFactor: primaryNegative,
      primaryPositiveFactor: primaryPositive,
      isCalibrating: base.isCalibrating,
      calibrationDay: base.calibrationDaysDone,
      isOffWrist: false,
    );
  }
}
