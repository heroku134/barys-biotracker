import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

enum RecoveryZone {
  optimal('Оптимально', AppColors.sage, 'Готово'),
  moderate('Умеренно', AppColors.amber, 'Норма'),
  recovery('Восстановление', AppColors.rose, 'Отдых');

  final String label;
  final Color color;
  final String badgeText;

  const RecoveryZone(this.label, this.color, this.badgeText);
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

  // Был ли снят браслет ночью
  final bool isOffWrist;

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
  });
}
