import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/personal_baseline.dart';

/// Модель суточного замера для калибровки бейзлайна
class DailyCalibrationSample {
  final int dayIndex; // 1..14
  final double hrv;
  final int rhr;
  final double respiratoryRate;
  final double skinTemp;
  final int sleepMinutes;
  final DateTime timestamp;

  const DailyCalibrationSample({
    required this.dayIndex,
    required this.hrv,
    required this.rhr,
    required this.respiratoryRate,
    required this.skinTemp,
    required this.sleepMinutes,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'dayIndex': dayIndex,
        'hrv': hrv,
        'rhr': rhr,
        'respiratoryRate': respiratoryRate,
        'skinTemp': skinTemp,
        'sleepMinutes': sleepMinutes,
        'timestamp': timestamp.toIso8601String(),
      };

  factory DailyCalibrationSample.fromJson(Map<String, dynamic> json) => DailyCalibrationSample(
        dayIndex: json['dayIndex'] as int,
        hrv: (json['hrv'] as num).toDouble(),
        rhr: json['rhr'] as int,
        respiratoryRate: (json['respiratoryRate'] as num).toDouble(),
        skinTemp: (json['skinTemp'] as num).toDouble(),
        sleepMinutes: json['sleepMinutes'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Математический менеджер 14-дневной адаптивной калибровки индивидуального бейзлайна
class BaselineCalibrationManager {
  static const String _prefKeySamples = 'kalkan_calibration_samples_v1';

  /// Загружает текущую персональную базовую линию из сохраненных замеров
  static Future<PersonalBaseline> loadCalibratedBaseline() async {
    final samples = await _loadSamples();
    if (samples.isEmpty) {
      return const PersonalBaseline(
        meanHrv: 64.0,
        stdHrv: 9.5,
        meanRhr: 52,
        meanRespiratoryRate: 14.4,
        baselineSkinTemp: 36.4,
        calibrationDaysDone: 14,
      );
    }

    // Расчет скользящих статистических метрик
    final n = samples.length;
    final hrvList = samples.map((s) => s.hrv).toList();
    final rhrList = samples.map((s) => s.rhr).toList();
    final rrList = samples.map((s) => s.respiratoryRate).toList();
    final tempList = samples.map((s) => s.skinTemp).toList();

    final meanHrv = hrvList.reduce((a, b) => a + b) / n;
    final meanRhr = (rhrList.reduce((a, b) => a + b) / n).round();
    final meanRr = rrList.reduce((a, b) => a + b) / n;
    final meanTemp = tempList.reduce((a, b) => a + b) / n;

    // Расчет стандартного отклонения (sigma)
    double stdHrv = 8.0;
    if (n > 1) {
      final variance = hrvList.map((x) => math.pow(x - meanHrv, 2)).reduce((a, b) => a + b) / (n - 1);
      stdHrv = math.sqrt(variance);
      if (stdHrv < 4.0) stdHrv = 4.0; // Защита от нулевого разброса
    }

    return PersonalBaseline(
      meanHrv: meanHrv,
      stdHrv: stdHrv,
      meanRhr: meanRhr,
      meanRespiratoryRate: double.parse(meanRr.toStringAsFixed(1)),
      baselineSkinTemp: double.parse(meanTemp.toStringAsFixed(1)),
      calibrationDaysDone: math.min(14, n),
    );
  }

  /// Добавляет новый ночной замер и пересчитывает адаптивную модель
  static Future<PersonalBaseline> recordNightSample({
    required double hrv,
    required int rhr,
    required double respiratoryRate,
    required double skinTemp,
    required int sleepMinutes,
  }) async {
    final samples = await _loadSamples();
    final nextDay = samples.length + 1;

    final newSample = DailyCalibrationSample(
      dayIndex: nextDay,
      hrv: hrv,
      rhr: rhr,
      respiratoryRate: respiratoryRate,
      skinTemp: skinTemp,
      sleepMinutes: sleepMinutes,
      timestamp: DateTime.now(),
    );

    samples.add(newSample);
    // Храним скользящее окно не более 30 дней
    if (samples.length > 30) {
      samples.removeAt(0);
    }

    await _saveSamples(samples);
    return loadCalibratedBaseline();
  }

  /// Возвращает уровень достоверности калибровки в процентах (30%..100%)
  static int calculateConfidence(int daysDone) {
    if (daysDone >= 14) return 100;
    if (daysDone >= 10) return 85;
    if (daysDone >= 7) return 70;
    if (daysDone >= 4) return 50;
    return 30;
  }

  /// Возвращает текстовое описание статуса калибровки
  static String getCalibrationStatusLabel(int daysDone) {
    if (daysDone >= 14) return 'БЕЙЗЛАЙН СКАЛИБРОВАН (100%)';
    if (daysDone >= 7) return 'ДЕНЬ $daysDone ИЗ 14 · ВЫСОКАЯ ТОЧНОСТЬ';
    return 'ДЕНЬ $daysDone ИЗ 14 · АКТИВНЫЙ СБОР ПАТТЕРНОВ';
  }

  /// Сбрасывает калибровку и начинает 14-дневный цикл заново
  static Future<void> resetCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeySamples);
  }

  static Future<List<DailyCalibrationSample>> _loadSamples() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKeySamples);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list.map((e) => DailyCalibrationSample.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('BaselineCalibrationManager._loadSamples error: $e');
      return [];
    }
  }

  static Future<void> _saveSamples(List<DailyCalibrationSample> samples) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(samples.map((e) => e.toJson()).toList());
      await prefs.setString(_prefKeySamples, raw);
    } catch (e) {
      debugPrint('BaselineCalibrationManager._saveSamples error: $e');
    }
  }
}
