import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';

/// Уровни стресса по строгой 3-цветной шкале CIRCA Quiet Luxury (Sage / Amber / Rose)
enum StressLevel {
  rest('Восстановление', AppColors.sage),
  low('Покой / Баланс', AppColors.sage),
  medium('Умеренный фокус', AppColors.amber),
  high('Высокий стресс', AppColors.rose);

  final String label;
  final Color color;

  const StressLevel(this.label, this.color);
}

class StressTimeSlot {
  final String id;
  final String timeRange; // e.g. "09:00 — 11:30"
  final String contextTitle; // e.g. "Утренний фокус / Работа"
  final String? userTag; // Пользовательская разметка («Переговоры», «Дедлайн», «Пробка»)
  final int stressScore; // 0..100
  final StressLevel level;
  final String physiologicalNote;
  final String barysReaction;
  final String barysAsset;

  const StressTimeSlot({
    required this.id,
    required this.timeRange,
    required this.contextTitle,
    this.userTag,
    required this.stressScore,
    required this.level,
    required this.physiologicalNote,
    required this.barysReaction,
    required this.barysAsset,
  });

  StressTimeSlot copyWith({
    String? userTag,
    String? contextTitle,
  }) {
    return StressTimeSlot(
      id: id,
      timeRange: timeRange,
      contextTitle: contextTitle ?? this.contextTitle,
      userTag: userTag ?? this.userTag,
      stressScore: stressScore,
      level: level,
      physiologicalNote: physiologicalNote,
      barysReaction: barysReaction,
      barysAsset: barysAsset,
    );
  }
}

class StressDaySummary {
  final int currentStressScore;
  final StressLevel currentLevel;
  final int minutesInHighStress;
  final int minutesInRestoration;
  final List<StressTimeSlot> timeline;

  const StressDaySummary({
    required this.currentStressScore,
    required this.currentLevel,
    required this.minutesInHighStress,
    required this.minutesInRestoration,
    required this.timeline,
  });
}

class StressEngine {
  static const String _prefPrefix = 'stress_slot_tag_';

  /// Сохранение пользовательской разметки слота
  static Future<void> saveSlotTag(String slotId, String tag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefPrefix$slotId', tag);
    } catch (_) {}
  }

  /// Получение сохраненного тега
  static Future<String?> getSlotTag(String slotId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_prefPrefix$slotId');
    } catch (_) {
      return null;
    }
  }

  static int scoreFromTelemetry(int currentScore, {int heartRate = 0, int restingHeartRate = 0}) {
    if (currentScore > 0) return currentScore.clamp(0, 100);
    if (heartRate <= 0) return 0;
    final rhr = restingHeartRate > 0 ? restingHeartRate : 60;
    return (((heartRate - rhr) / 80.0) * 100).round().clamp(0, 100);
  }

  static StressLevel levelFor(int score) {
    if (score >= 70) return StressLevel.high;
    if (score >= 35) return StressLevel.medium;
    return StressLevel.rest;
  }

  /// Лента дня только из того, что есть: сон, текущий пульс/стресс, нагрузка.
  /// Минутной ВСР с часов нет — выдуманные «38 мс в 13:30» больше не показываем.
  static StressDaySummary analyze({
    required int currentScore,
    Map<String, String>? customTags,
    int heartRate = 0,
    int restingHeartRate = 0,
    double hrv = 0,
    double meanHrv = 0,
    int sleepMinutes = 0,
    double dayStrain = 0,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final score = scoreFromTelemetry(currentScore, heartRate: heartRate, restingHeartRate: restingHeartRate);
    final currentLevel = levelFor(score);
    final tags = customTags ?? {};
    final timeline = <StressTimeSlot>[];

    if (sleepMinutes > 0) {
      final hours = sleepMinutes / 60.0;
      timeline.add(StressTimeSlot(
        id: 'slot_sleep',
        timeRange: 'Ночь',
        contextTitle: tags['slot_sleep'] ?? 'Сон',
        userTag: tags['slot_sleep'],
        stressScore: hours >= 7 ? 22 : (hours >= 6 ? 40 : 62),
        level: hours >= 7 ? StressLevel.rest : (hours >= 6 ? StressLevel.medium : StressLevel.high),
        physiologicalNote: hours >= 7
            ? 'Сон ${hours.toStringAsFixed(1)} ч.'
            : 'Сон ${hours.toStringAsFixed(1)} ч — короче обычной нормы 7.5.',
        barysReaction: hours >= 7 ? 'Ночь закрыта.' : 'Ночь коротковата.',
        barysAsset: 'assets/images/mascot_sleep.jpg',
      ));
    }

    final hrLine = heartRate > 0 ? 'Пульс $heartRate.' : 'Пульса с часов нет.';
    final hrvLine = hrv > 0 && meanHrv > 0
        ? ' HRV ${hrv.toStringAsFixed(0)} при норме ${meanHrv.toStringAsFixed(0)}.'
        : (hrv > 0 ? ' HRV ${hrv.toStringAsFixed(0)}.' : '');
    timeline.add(StressTimeSlot(
      id: 'slot_now',
      timeRange: '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
      contextTitle: tags['slot_now'] ?? 'Сейчас',
      userTag: tags['slot_now'],
      stressScore: score,
      level: currentLevel,
      physiologicalNote: '$hrLine$hrvLine',
      barysReaction: score >= 70
          ? 'Стресс высокий. Пауза лучше ещё одной задачи.'
          : (score >= 35 ? 'Рабочий тон. Без пика.' : 'Спокойно.'),
      barysAsset: score >= 70
          ? 'assets/images/mascot_tired.jpg'
          : (score >= 35 ? 'assets/images/mascot_normal.jpg' : 'assets/images/mascot_charged.jpg'),
    ));

    if (dayStrain > 0) {
      timeline.add(StressTimeSlot(
        id: 'slot_strain',
        timeRange: 'День',
        contextTitle: tags['slot_strain'] ?? 'Нагрузка',
        userTag: tags['slot_strain'],
        stressScore: (40 + dayStrain * 2).round().clamp(20, 90),
        level: dayStrain >= 16 ? StressLevel.high : (dayStrain >= 10 ? StressLevel.medium : StressLevel.rest),
        physiologicalNote: 'Накопленный strain ${dayStrain.toStringAsFixed(1)} из 21.',
        barysReaction: dayStrain >= 16 ? 'Бюджет дня выбран.' : 'Нагрузка идёт.',
        barysAsset: 'assets/images/mascot_workout.jpg',
      ));
    }

    final highMin = score >= 70 ? 20 : 0;
    final restMin = score < 35 ? 30 : 0;

    return StressDaySummary(
      currentStressScore: score,
      currentLevel: currentLevel,
      minutesInHighStress: highMin,
      minutesInRestoration: restMin,
      timeline: timeline,
    );
  }
}
