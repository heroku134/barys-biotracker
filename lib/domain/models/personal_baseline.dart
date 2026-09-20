import 'package:flutter/foundation.dart';

/// Персональный 60-дневный базовый профиль пользователя (Whoop / Oura Baseline)
/// Все ночные маркеры сравниваются не с усредненными таблицами, а с личной нормой.
@immutable
class PersonalBaseline {
  /// Личная медиана ночного rMSSD ВСР (мс)
  final double meanHrv;
  /// Стандартное отклонение ВСР (мс)
  final double stdHrv;

  /// Ночной пульс покоя в глубоком сне (RHR Nadir, bpm)
  final int meanRhr;

  /// Средняя ночная частота дыхания (вдохов в минуту)
  final double meanRespiratoryRate;

  /// Базовая ночная температура кожи (°C)
  final double baselineSkinTemp;

  /// Индивидуальная суточная потребность во сне (минут, обычно 450-510 мин / 7.5-8.5 ч)
  final int baselineSleepNeedMinutes;

  /// Текущий день калибровки (1..14). Если < 14, действует калибровочный профиль
  final int calibrationDaysDone;

  /// Накопленный долг сна за последние 14 дней (минут)
  final int sleepDebtMinutes;

  /// Нагрузка за вчерашний день (Strain 0-21)
  final double yesterdayStrain;

  /// История оценок восстановления за последние 3 дня (для детекции затяжного истощения/болезни)
  final List<int> recentRecoveryScores;

  /// Фаза гормонального цикла (если включен)
  final HormoneCyclePhase? cyclePhase;

  const PersonalBaseline({
    this.meanHrv = 64.0,
    this.stdHrv = 9.5,
    this.meanRhr = 52,
    this.meanRespiratoryRate = 14.4,
    this.baselineSkinTemp = 36.4,
    this.baselineSleepNeedMinutes = 480, // 8 часов
    this.calibrationDaysDone = 14, // По умолчанию откалиброван (можно выставить <14 для демо)
    this.sleepDebtMinutes = 25, // 25 мин дефицита
    this.yesterdayStrain = 11.2,
    this.recentRecoveryScores = const [78, 65, 72],
    this.cyclePhase,
  });

  bool get isCalibrating => calibrationDaysDone < 14;

  /// Персональный допустимый коридор нормы ВСР (ВСР в пределах ±1.0 SD считается нормой)
  double get hrvNormalMin => meanHrv - stdHrv;
  double get hrvNormalMax => meanHrv + (stdHrv * 1.5);

  /// Допустимый коридор пульса покоя
  int get rhrNormalMax => meanRhr + 3;

  /// Допустимое отклонение частоты дыхания (обычно не более ±1.0 вдоха)
  double get rrNormalMax => meanRespiratoryRate + 1.2;

  PersonalBaseline copyWith({
    double? meanHrv,
    double? stdHrv,
    int? meanRhr,
    double? meanRespiratoryRate,
    double? baselineSkinTemp,
    int? baselineSleepNeedMinutes,
    int? calibrationDaysDone,
    int? sleepDebtMinutes,
    double? yesterdayStrain,
    List<int>? recentRecoveryScores,
    HormoneCyclePhase? cyclePhase,
  }) {
    return PersonalBaseline(
      meanHrv: meanHrv ?? this.meanHrv,
      stdHrv: stdHrv ?? this.stdHrv,
      meanRhr: meanRhr ?? this.meanRhr,
      meanRespiratoryRate: meanRespiratoryRate ?? this.meanRespiratoryRate,
      baselineSkinTemp: baselineSkinTemp ?? this.baselineSkinTemp,
      baselineSleepNeedMinutes: baselineSleepNeedMinutes ?? this.baselineSleepNeedMinutes,
      calibrationDaysDone: calibrationDaysDone ?? this.calibrationDaysDone,
      sleepDebtMinutes: sleepDebtMinutes ?? this.sleepDebtMinutes,
      yesterdayStrain: yesterdayStrain ?? this.yesterdayStrain,
      recentRecoveryScores: recentRecoveryScores ?? this.recentRecoveryScores,
      cyclePhase: cyclePhase ?? this.cyclePhase,
    );
  }
}

enum HormoneCyclePhase {
  follicular('Фолликулярная фаза', 'Пик энергии и анаболизма. Оптимально для тяжелых нагрузок.'),
  ovulatory('Овуляция', 'Высокий тонус, пиковые силовые показатели.'),
  luteal('Лютеиновая фаза', 'Естественный рост температуры (+0.3..+0.5°C) и снижение ВСР. Это физиологическая норма, не паникуйте.'),
  menstrual('Менструальная фаза', 'Фаза регенерации. Рекомендуется умеренный Strain.');

  final String title;
  final String note;

  const HormoneCyclePhase(this.title, this.note);
}
