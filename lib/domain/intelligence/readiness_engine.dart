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
        hasHrv: false,
        hasRhr: false,
        hasSleep: false,
        hasRr: false,
        hasTemp: false,
        hasSufficientData: false,
      );
    }

    final hasHrv = telemetry.hasHrv;
    final hasRhr = telemetry.hasRhr;
    final hasSleep = telemetry.hasSleep;
    final hasRr = telemetry.hasRespiratoryRate;
    final hasTemp = telemetry.hasSkinTempDeviation;

    // Если нет ни одного реального ночного биомаркера — честно сообщаем об отсутствии данных
    if (!hasHrv && !hasRhr && !hasSleep && !hasRr && !hasTemp) {
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
        hrvDiffPercent: 0,
        currentRhr: 0,
        baselineRhr: base.meanRhr,
        rhrDiffBpm: 0,
        currentRr: 0,
        baselineRr: base.meanRespiratoryRate,
        tempDiffCelsius: 0,
        primaryNegativeFactor: 'Ожидание ночных биомаркеров',
        primaryPositiveFactor: 'Требуется запись сна',
        isCalibrating: base.isCalibrating,
        calibrationDay: base.calibrationDaysDone,
        isOffWrist: false,
        hasHrv: false,
        hasRhr: false,
        hasSleep: false,
        hasRr: false,
        hasTemp: false,
        hasSufficientData: false,
      );
    }

    // 2. Оценка ВСР (rMSSD) относительно личной медианы (канонический вес 0.35)
    final int hrvScore;
    final int hrvDiffPercent;
    if (hasHrv) {
      final hrvRatio = telemetry.hrv / math.max(10.0, base.meanHrv);
      hrvDiffPercent = (((telemetry.hrv - base.meanHrv) / base.meanHrv) * 100).round();
      hrvScore = (hrvRatio * 85.0).clamp(10.0, 100.0).round();
    } else {
      hrvScore = 0;
      hrvDiffPercent = 0;
    }

    // 3. Оценка ночного пульса покоя (RHR Nadir в глубоком сне, канонический вес 0.25)
    final int rhrScore;
    final int rhrDiffBpm;
    if (hasRhr) {
      rhrDiffBpm = telemetry.restingHeartRate - base.meanRhr;
      final double rhrNormalized;
      if (rhrDiffBpm <= 0) {
        rhrNormalized = 95.0 + (-rhrDiffBpm * 2.5).clamp(0.0, 5.0);
      } else {
        rhrNormalized = 90.0 - (rhrDiffBpm * 7.5);
      }
      rhrScore = rhrNormalized.clamp(15.0, 100.0).round();
    } else {
      rhrScore = 0;
      rhrDiffBpm = 0;
    }

    // 4. Оценка сна из SleepEngine (канонический вес 0.20)
    final int sleepScore;
    if (hasSleep) {
      final sleepAnalysis = SleepEngine.calculate(telemetry: telemetry, baseline: base);
      sleepScore = sleepAnalysis.sleepPerformanceScore;
    } else {
      sleepScore = 0;
    }

    // 5. Оценка частоты дыхания (RR, канонический вес 0.10) — строго если есть реальный замер
    final int rrScore;
    if (hasRr) {
      final rrDiff = telemetry.respiratoryRate - base.meanRespiratoryRate;
      final double rrNormalized;
      if (rrDiff.abs() <= 0.6) {
        rrNormalized = 98.0;
      } else {
        rrNormalized = 95.0 - (rrDiff.abs() * 25.0);
      }
      rrScore = rrNormalized.clamp(20.0, 100.0).round();
    } else {
      rrScore = 0;
    }

    // 6. Оценка отклонения температуры кожи (ΔT, канонический вес 0.10) — строго если есть реальный замер
    final int tempScore;
    final double tempDiff = telemetry.skinTempDeviation;
    if (hasTemp) {
      final double tempNormalized;
      if (tempDiff.abs() <= 0.2) {
        tempNormalized = 98.0;
      } else if (tempDiff > 0.2) {
        tempNormalized = 95.0 - ((tempDiff - 0.2) * 60.0);
      } else {
        tempNormalized = 90.0 - ((tempDiff.abs() - 0.2) * 30.0);
      }
      tempScore = tempNormalized.clamp(15.0, 100.0).round();
    } else {
      tempScore = 0;
    }

    // 7. Динамическая ренормализация весов:
    // Учитываются ТОЛЬКО реально присутствующие сенсорные компоненты!
    // Сумма весов имеющихся компонентов масштабируется до 100%.
    double totalWeight = 0.0;
    double weightedSum = 0.0;

    if (hasHrv) {
      totalWeight += 0.35;
      weightedSum += 0.35 * hrvScore;
    }
    if (hasRhr) {
      totalWeight += 0.25;
      weightedSum += 0.25 * rhrScore;
    }
    if (hasSleep) {
      totalWeight += 0.20;
      weightedSum += 0.20 * sleepScore;
    }
    if (hasRr) {
      totalWeight += 0.10;
      weightedSum += 0.10 * rrScore;
    }
    if (hasTemp) {
      totalWeight += 0.10;
      weightedSum += 0.10 * tempScore;
    }

    final finalScore = totalWeight > 0.0
        ? (weightedSum / totalWeight).round().clamp(0, 100)
        : 0;

    final RecoveryZone zone;
    if (finalScore >= 67) {
      zone = RecoveryZone.optimal;
    } else if (finalScore >= 34) {
      zone = RecoveryZone.moderate;
    } else {
      zone = RecoveryZone.recovery;
    }

    // Вычисление динамических процентов вклада для UI (в сумме 100%)
    final hrvWeightPct = hasHrv ? ((0.35 / totalWeight) * 100).round() : 0;
    final rhrWeightPct = hasRhr ? ((0.25 / totalWeight) * 100).round() : 0;
    final sleepWeightPct = hasSleep ? ((0.20 / totalWeight) * 100).round() : 0;
    final rrWeightPct = hasRr ? ((0.10 / totalWeight) * 100).round() : 0;
    final tempWeightPct = hasTemp ? ((0.10 / totalWeight) * 100).round() : 0;

    // Определение главных драйверов только среди измеренных компонентов
    final factors = <({String name, int score, String desc})>[];
    if (hasHrv) {
      factors.add((name: 'ВСР (rMSSD)', score: hrvScore, desc: '$hrvDiffPercent% vs базы'));
    }
    if (hasRhr) {
      factors.add((name: 'Пульс покоя', score: rhrScore, desc: '${rhrDiffBpm >= 0 ? "+$rhrDiffBpm" : "$rhrDiffBpm"} bpm vs базы'));
    }
    if (hasSleep) {
      factors.add((name: 'Качество сна', score: sleepScore, desc: '$sleepScore% от потребности'));
    }
    if (hasRr) {
      factors.add((name: 'Частота дыхания', score: rrScore, desc: '${telemetry.respiratoryRate.toStringAsFixed(1)} вдохов/мин'));
    }
    if (hasTemp) {
      factors.add((name: 'Температура кожи', score: tempScore, desc: '${tempDiff >= 0 ? "+$tempDiff" : "$tempDiff"}°C'));
    }

    final String primaryNegative;
    final String primaryPositive;
    if (factors.isEmpty) {
      primaryNegative = 'Ожидание ночных биомаркеров';
      primaryPositive = 'Калибровка';
    } else {
      factors.sort((a, b) => a.score.compareTo(b.score));
      primaryNegative = '${factors.first.name} (${factors.first.desc}) — главный сдерживающий фактор';
      primaryPositive = '${factors.last.name} (${factors.last.desc}) — ключевой драйвер восстановления';
    }

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
      hasHrv: hasHrv,
      hasRhr: hasRhr,
      hasSleep: hasSleep,
      hasRr: hasRr,
      hasTemp: hasTemp,
      hasSufficientData: totalWeight > 0.0,
      hrvWeightPct: hrvWeightPct,
      rhrWeightPct: rhrWeightPct,
      sleepWeightPct: sleepWeightPct,
      rrWeightPct: rrWeightPct,
      tempWeightPct: tempWeightPct,
    );
  }
}
