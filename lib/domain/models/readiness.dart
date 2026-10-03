import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';

enum RecoveryZone {
  optimal('Оптимально', AppColors.sage, 'Готово'),
  moderate('Умеренно', AppColors.amber, 'Норма'),
  recovery('Восстановление', AppColors.rose, 'Отдых');

  final String label;
  final Color color;
  final String badgeText;

  const RecoveryZone(this.label, this.color, this.badgeText);

  /// Реактивная локализованная подпись зоны, учитывающая текущий язык интерфейса
  String get localizedLabel {
    switch (this) {
      case RecoveryZone.optimal:
        return AppLocaleNotifier.t('Оптимально', 'Оптималдуу', 'Optimal');
      case RecoveryZone.moderate:
        return AppLocaleNotifier.t('Умеренно', 'Орточо', 'Moderate');
      case RecoveryZone.recovery:
        return AppLocaleNotifier.t('Восстановление', 'Калыбына келүү', 'Recovery');
    }
  }

  /// Реактивный локализованный бейдж готовности
  String get localizedBadge {
    switch (this) {
      case RecoveryZone.optimal:
        return AppLocaleNotifier.t('Готово', 'Даяр', 'Ready');
      case RecoveryZone.moderate:
        return AppLocaleNotifier.t('Норма', 'Кадыресе', 'Adequate');
      case RecoveryZone.recovery:
        return AppLocaleNotifier.t('Отдых', 'Эс алуу', 'Rest');
    }
  }

  /// Название зоны для заданного языка
  String localizedName([AppLanguage? language]) {
    final lang = language ?? AppLocaleNotifier.current;
    switch (this) {
      case RecoveryZone.optimal:
        return lang == AppLanguage.kyrgyz ? 'Оптималдуу' : (lang == AppLanguage.english ? 'Optimal' : 'Оптимально');
      case RecoveryZone.moderate:
        return lang == AppLanguage.kyrgyz ? 'Орточо' : (lang == AppLanguage.english ? 'Moderate' : 'Умеренно');
      case RecoveryZone.recovery:
        return lang == AppLanguage.kyrgyz ? 'Калыбына келүү' : (lang == AppLanguage.english ? 'Recovery' : 'Восстановление');
    }
  }

  /// Разрешение цвета зоны
  Color resolveColor([BuildContext? context]) => color;
}

class ReadinessResult {
  final int score;
  final RecoveryZone zone;

  // 5 ночных компонентов формулы:
  // Recovery = 0.35·HRV + 0.25·RHR + 0.20·Sleep + 0.10·RR + 0.10·Temp
  final int hrvFactor; // 0..100
  final int rhrFactor; // 0..100
  final int sleepFactor; // 0..100
  final int rrFactor; // 0..100
  final int tempFactor; // 0..100

  // Сравнение с личным Baseline для разбора по тапу
  final double currentHrv;
  final double baselineHrv;
  final int hrvDiffPercent; // напр. -36%

  final int currentRhr;
  final int baselineRhr;
  final int rhrDiffBpm; // напр. +2 bpm

  final double currentRr;
  final double baselineRr;

  final double tempDiffCelsius; // напр. +0.3°C

  // Анализ главных факторов
  final String primaryNegativeFactor;
  final String primaryPositiveFactor;

  // Режим калибровки первых 14 дней
  final bool isCalibrating;
  final int calibrationDay;
  final bool isOffWrist;

  // Доступность ночных компонентов
  final bool hasHrv;
  final bool hasRhr;
  final bool hasSleep;
  final bool hasRr;
  final bool hasTemp;
  final bool hasSufficientData;

  // Динамические веса (в процентах, сумма активных = 100%)
  final int hrvWeightPct;
  final int rhrWeightPct;
  final int sleepWeightPct;
  final int rrWeightPct;
  final int tempWeightPct;

  const ReadinessResult({
    required this.score,
    required this.zone,
    required this.hrvFactor,
    required this.rhrFactor,
    required this.sleepFactor,
    required this.rrFactor,
    required this.tempFactor,
    required this.currentHrv,
    required this.baselineHrv,
    required this.hrvDiffPercent,
    required this.currentRhr,
    required this.baselineRhr,
    required this.rhrDiffBpm,
    required this.currentRr,
    required this.baselineRr,
    required this.tempDiffCelsius,
    required this.primaryNegativeFactor,
    required this.primaryPositiveFactor,
    this.isCalibrating = false,
    this.calibrationDay = 14,
    this.isOffWrist = false,
    this.hasHrv = true,
    this.hasRhr = true,
    this.hasSleep = true,
    this.hasRr = false,
    this.hasTemp = false,
    this.hasSufficientData = true,
    this.hrvWeightPct = 35,
    this.rhrWeightPct = 25,
    this.sleepWeightPct = 20,
    this.rrWeightPct = 10,
    this.tempWeightPct = 10,
  });
}
