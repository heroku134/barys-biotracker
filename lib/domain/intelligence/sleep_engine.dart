import 'dart:math' as math;
import '../models/personal_baseline.dart';
import '../models/telemetry.dart';

class SleepAnalysisResult {
  /// Рассчитанная потребность во сне на сегодня (минут)
  final int sleepNeedMinutes;

  /// Базовая потребность (минут)
  final int baselineNeedMinutes;

  /// Добавка за накопленный долг сна (минут)
  final int sleepDebtPortionMinutes;

  /// Добавка за физическую нагрузку Strain (минут)
  final int strainSurchargeMinutes;

  /// Фактический сон (минут)
  final int actualSleepMinutes;

  /// Итоговая оценка качества сна (0..100%)
  final int sleepPerformanceScore;

  // 4 слагаемых Whoop Sleep Performance:
  final int durationFactor; // Actual / Need (%)
  final int efficiencyFactor; // Sleep / Time in Bed (%)
  final int consistencyFactor; // Регулярность отхода ко сну (%)
  final int restorativeFactor; // Сон с пульсом ниже RHR (%)

  /// Рекомендованное время отхода ко сну для 100% покрытия потребности
  final String optimalBedtime;

  /// Гипнограмма сна
  final List<SleepEpoch> hypnogram;

  const SleepAnalysisResult({
    required this.sleepNeedMinutes,
    required this.baselineNeedMinutes,
    required this.sleepDebtPortionMinutes,
    required this.strainSurchargeMinutes,
    required this.actualSleepMinutes,
    required this.sleepPerformanceScore,
    required this.durationFactor,
    required this.efficiencyFactor,
    required this.consistencyFactor,
    required this.restorativeFactor,
    required this.optimalBedtime,
    required this.hypnogram,
  });
}

class SleepEngine {
  /// Анализ сна по телеметрии
  static SleepAnalysisResult analyze(BleTelemetry telemetry, {PersonalBaseline baseline = const PersonalBaseline()}) =>
      calculate(telemetry: telemetry, baseline: baseline);

  /// Расчет динамической потребности во сне (Whoop Sleep Planner)
  static SleepAnalysisResult calculate({
    required BleTelemetry telemetry,
    PersonalBaseline baseline = const PersonalBaseline(),
    int targetWakeHour = 7,
    int targetWakeMinute = 0,
  }) {
    // 1. Базовая потребность (7.5 - 8.5 часов)
    final baseNeed = baseline.baselineSleepNeedMinutes;

    // 2. Списание накопленного за 14 дней долга сна (гасится порциями по 25% в сутки)
    final debtPortion = (baseline.sleepDebtMinutes * 0.25).round();

    // 3. Доплата за вчерашнюю/накопленную нагрузку Strain
    // При Strain > 10.0 добавляется 1.6 мин за каждый балл (Strain 17 дает ~35-45 мин доплаты)
    final strainDiff = math.max(0.0, telemetry.yesterdayStrain - 10.0);
    final strainSurcharge = (strainDiff * 1.6).round();

    final totalSleepNeed = baseNeed + debtPortion + strainSurcharge;

    // 4 фактора качества сна:
    // А. Длительность против потребности
    final durationFactor = ((telemetry.sleepMinutes / totalSleepNeed) * 100).round().clamp(0, 100);

    // Б. Эффективность (сон / постель)
    final efficiencyFactor = (telemetry.sleepEfficiency * 100).round().clamp(0, 100);

    // В. Consistency (регулярность отхода и подъема)
    final consistencyFactor = (telemetry.sleepConsistency * 100).round().clamp(0, 100);

    // Г. Ночной стресс / Релаксация (пульс ниже дневного RHR)
    final restorativeFactor = (telemetry.restorativeSleepRatio * 100).round().clamp(0, 100);

    // Взвешенный Sleep Performance
    final performanceScore = (durationFactor * 0.40 +
            efficiencyFactor * 0.25 +
            consistencyFactor * 0.20 +
            restorativeFactor * 0.15)
        .round()
        .clamp(0, 100);

    // Рекомендованное время отбоя при целевом подъеме в targetWakeHour:targetWakeMinute
    // Требуемое время в кровати = need / efficiency
    final neededInBed = (totalSleepNeed / math.max(0.80, telemetry.sleepEfficiency)).round();
    final wakeTotalMinutes = targetWakeHour * 60 + targetWakeMinute;
    var bedTotalMinutes = wakeTotalMinutes - neededInBed;
    if (bedTotalMinutes < 0) bedTotalMinutes += 24 * 60;
    final bedHour = bedTotalMinutes ~/ 60;
    final bedMinute = bedTotalMinutes % 60;
    final bedHourStr = bedHour.toString().padLeft(2, '0');
    final bedMinuteStr = bedMinute.toString().padLeft(2, '0');
    final optimalBedtime = '$bedHourStr:$bedMinuteStr';

    // Гипнограмма
    final hypnogram = telemetry.sleepHypnogram.isNotEmpty
        ? telemetry.sleepHypnogram
        : _generateSampleHypnogram(telemetry.sleepMinutes);

    return SleepAnalysisResult(
      sleepNeedMinutes: totalSleepNeed,
      baselineNeedMinutes: baseNeed,
      sleepDebtPortionMinutes: debtPortion,
      strainSurchargeMinutes: strainSurcharge,
      actualSleepMinutes: telemetry.sleepMinutes,
      sleepPerformanceScore: performanceScore,
      durationFactor: durationFactor,
      efficiencyFactor: efficiencyFactor,
      consistencyFactor: consistencyFactor,
      restorativeFactor: restorativeFactor,
      optimalBedtime: optimalBedtime,
      hypnogram: hypnogram,
    );
  }

  /// Генерация реалистичной цикличной гипнограммы (90-минутные ультрадианные циклы)
  static List<SleepEpoch> _generateSampleHypnogram(int totalMinutes) {
    final epochs = <SleepEpoch>[];
    final baseTime = DateTime.now().subtract(Duration(minutes: totalMinutes + 35));
    var cursor = baseTime;

    // Начальное засыпание (бодрствование -> легкий сон)
    epochs.add(SleepEpoch(
      startTime: cursor,
      endTime: cursor.add(const Duration(minutes: 15)),
      stage: SleepStageType.awake,
    ));
    cursor = cursor.add(const Duration(minutes: 15));

    // Циклы (по 90-100 мин): Легкий -> Глубокий -> Легкий -> REM
    final cycles = (totalMinutes / 95).ceil();
    for (var i = 0; i < cycles; i++) {
      // 1. Легкий сон (25-30 мин)
      epochs.add(SleepEpoch(
        startTime: cursor,
        endTime: cursor.add(const Duration(minutes: 25)),
        stage: SleepStageType.light,
      ));
      cursor = cursor.add(const Duration(minutes: 25));

      // 2. Глубокий сон (в первой половине ночи длиннее, во второй короче)
      final deepDuration = i < 2 ? 35 : 12;
      epochs.add(SleepEpoch(
        startTime: cursor,
        endTime: cursor.add(Duration(minutes: deepDuration)),
        stage: SleepStageType.deep,
      ));
      cursor = cursor.add(Duration(minutes: deepDuration));

      // 3. Легкий сон переходной (15 мин)
      epochs.add(SleepEpoch(
        startTime: cursor,
        endTime: cursor.add(const Duration(minutes: 15)),
        stage: SleepStageType.light,
      ));
      cursor = cursor.add(const Duration(minutes: 15));

      // 4. REM (быстрый сон: под утро длиннее)
      final remDuration = i < 2 ? 18 : 32;
      epochs.add(SleepEpoch(
        startTime: cursor,
        endTime: cursor.add(Duration(minutes: remDuration)),
        stage: SleepStageType.rem,
      ));
      cursor = cursor.add(Duration(minutes: remDuration));

      // Краткое микропробуждение WASO
      if (i == 1 || i == 3) {
        epochs.add(SleepEpoch(
          startTime: cursor,
          endTime: cursor.add(const Duration(minutes: 4)),
          stage: SleepStageType.awake,
        ));
        cursor = cursor.add(const Duration(minutes: 4));
      }
    }

    return epochs;
  }
}
