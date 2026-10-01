import 'package:flutter/foundation.dart';

/// Фаза сна для построения честной гипнограммы
enum SleepStageType {
  awake('Бодрствование'),
  light('Легкий сон'),
  rem('Быстрый сон (REM)'),
  deep('Глубокий сон');

  final String title;
  const SleepStageType(this.title);
}

@immutable
class SleepEpoch {
  final DateTime startTime;
  final DateTime endTime;
  final SleepStageType stage;

  const SleepEpoch({
    required this.startTime,
    required this.endTime,
    required this.stage,
  });

  int get durationMinutes => endTime.difference(startTime).inMinutes;
}

/// Модель биометрических данных в реальном времени с датчиков устройства
@immutable
class BleTelemetry {
  // Мгновенный пульс и активность
  final int heartRate;
  final int steps;
  final int calories;
  final int batteryLevel;
  final bool isCharging;
  final bool isConnected;
  final String deviceName;
  final DateTime timestamp;

  // Ночные биомаркеры (строго NREM/глубокий сон)
  final double hrv; // rMSSD в мс
  final int restingHeartRate; // RHR Nadir глубокого сна (bpm)
  final double respiratoryRate; // Частота дыхания (вдохов/мин)
  final double skinTempDeviation; // Отклонение температуры кожи от личной нормы (°C, напр. +0.1)
  final bool isOffWrist; // Флаг: был ли снят браслет ночью (данные бракуются)

  // Показатели сна
  final int sleepMinutes; // Фактическое время сна
  final int deepSleepMinutes; // Глубокая фаза
  final int remSleepMinutes; // Быстрый сон
  final int timeInBedMinutes; // Общее время в постели
  final double sleepEfficiency; // Фактический сон / время в кровати (0.0 .. 1.0)
  final double sleepConsistency; // Регулярность отхода ко сну (0.0 .. 1.0)
  final double restorativeSleepRatio; // Доля сна с пульсом ниже дневного RHR (0.0 .. 1.0)
  final List<SleepEpoch> sleepHypnogram; // Данные для гипнограммы

  // Нагрузка (Whoop TRIMP)
  final double currentDayStrain; // Текущий накопленный Strain дня (0.0 .. 21.0)
  final double yesterdayStrain; // Вчерашний Strain (для расчета надбавки ко сну)
  final List<int> zoneMinutes; // [Зона 1, Зона 2, Зона 3, Зона 4, Зона 5] в минутах

  // Дневной стресс
  final int currentStressScore; // 0..100

  const BleTelemetry({
    this.heartRate = 0,
    this.steps = 0,
    this.calories = 0,
    this.batteryLevel = 0,
    this.isCharging = false,
    this.isConnected = false,
    this.deviceName = 'СААТ-1',
    required this.timestamp,

    // Ночные маркеры
    this.hrv = 0.0,
    this.restingHeartRate = 0,
    this.respiratoryRate = 0.0,
    this.skinTempDeviation = 0.0,
    this.isOffWrist = false,

    // Сон
    this.sleepMinutes = 0,
    this.deepSleepMinutes = 0,
    this.remSleepMinutes = 0,
    this.timeInBedMinutes = 0,
    this.sleepEfficiency = 0.0,
    this.sleepConsistency = 0.0,
    this.restorativeSleepRatio = 0.0,
    this.sleepHypnogram = const [],

    // Нагрузка
    this.currentDayStrain = 0.0,
    this.yesterdayStrain = 0.0,
    this.zoneMinutes = const [0, 0, 0, 0, 0],

    // Стресс
    this.currentStressScore = 0,
  });

  factory BleTelemetry.empty() => BleTelemetry(
        timestamp: DateTime.now(),
      );

  BleTelemetry copyWith({
    int? heartRate,
    int? steps,
    int? calories,
    int? batteryLevel,
    bool? isCharging,
    bool? isConnected,
    String? deviceName,
    DateTime? timestamp,
    double? hrv,
    int? restingHeartRate,
    double? respiratoryRate,
    double? skinTempDeviation,
    bool? isOffWrist,
    int? sleepMinutes,
    int? deepSleepMinutes,
    int? remSleepMinutes,
    int? timeInBedMinutes,
    double? sleepEfficiency,
    double? sleepConsistency,
    double? restorativeSleepRatio,
    List<SleepEpoch>? sleepHypnogram,
    double? currentDayStrain,
    double? yesterdayStrain,
    List<int>? zoneMinutes,
    int? currentStressScore,
  }) {
    return BleTelemetry(
      heartRate: heartRate ?? this.heartRate,
      steps: steps ?? this.steps,
      calories: calories ?? this.calories,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      isConnected: isConnected ?? this.isConnected,
      deviceName: deviceName ?? this.deviceName,
      timestamp: timestamp ?? this.timestamp,
      hrv: hrv ?? this.hrv,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      skinTempDeviation: skinTempDeviation ?? this.skinTempDeviation,
      isOffWrist: isOffWrist ?? this.isOffWrist,
      sleepMinutes: sleepMinutes ?? this.sleepMinutes,
      deepSleepMinutes: deepSleepMinutes ?? this.deepSleepMinutes,
      remSleepMinutes: remSleepMinutes ?? this.remSleepMinutes,
      timeInBedMinutes: timeInBedMinutes ?? this.timeInBedMinutes,
      sleepEfficiency: sleepEfficiency ?? this.sleepEfficiency,
      sleepConsistency: sleepConsistency ?? this.sleepConsistency,
      restorativeSleepRatio: restorativeSleepRatio ?? this.restorativeSleepRatio,
      sleepHypnogram: sleepHypnogram ?? this.sleepHypnogram,
      currentDayStrain: currentDayStrain ?? this.currentDayStrain,
      yesterdayStrain: yesterdayStrain ?? this.yesterdayStrain,
      zoneMinutes: zoneMinutes ?? this.zoneMinutes,
      currentStressScore: currentStressScore ?? this.currentStressScore,
    );
  }
}
