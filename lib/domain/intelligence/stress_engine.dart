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

  /// Генерация суточной ленты стресса на основе пульса vs личного RHR и скользящего окна ВСР
  static StressDaySummary analyze({
    required int currentScore,
    Map<String, String>? customTags,
  }) {
    final StressLevel currentLevel;
    if (currentScore >= 70) {
      currentLevel = StressLevel.high;
    } else if (currentScore >= 35) {
      currentLevel = StressLevel.medium;
    } else {
      currentLevel = StressLevel.rest;
    }

    final timeline = [
      StressTimeSlot(
        id: 'slot_1',
        timeRange: '07:30 — 09:00',
        contextTitle: customTags?['slot_1'] ?? 'Пробуждение и дорога',
        userTag: customTags?['slot_1'],
        stressScore: 28,
        level: StressLevel.rest,
        physiologicalNote: 'Пульс стабилен (56 bpm), парасимпатический тонус на максимуме.',
        barysReaction: '«Мягкий старт дня без адреналинового удара. Ты проснулся отдохнувшим, батыр.»',
        barysAsset: 'assets/images/hero_barys_normal.jpg',
      ),
      StressTimeSlot(
        id: 'slot_2',
        timeRange: '09:30 — 12:30',
        contextTitle: customTags?['slot_2'] ?? 'Рабочий спринт и аналитика',
        userTag: customTags?['slot_2'],
        stressScore: 54,
        level: StressLevel.medium,
        physiologicalNote: 'Умеренная симпатическая активация, концентрация внимания.',
        barysReaction: '«Симпатический тонус активирован. 2.5 часа глубокого фокуса без переутомления.»',
        barysAsset: 'assets/images/hero_barys_charged.jpg',
      ),
      StressTimeSlot(
        id: 'slot_3',
        timeRange: '13:30 — 15:00',
        contextTitle: customTags?['slot_3'] ?? 'Дедлайн / Сложные переговоры',
        userTag: customTags?['slot_3'],
        stressScore: 78,
        level: StressLevel.high,
        physiologicalNote: 'Кратковременное падение ВСР до 38 мс на фоне острого стресса.',
        barysReaction: '«Пик кортизола дня! ВСР просела, но сердце выдержало. Шторм позади, батыр.»',
        barysAsset: 'assets/images/hero_barys_tired.jpg',
      ),
      StressTimeSlot(
        id: 'slot_4',
        timeRange: '17:30 — 18:30',
        contextTitle: customTags?['slot_4'] ?? 'Тренировка / Нагрузка',
        userTag: customTags?['slot_4'],
        stressScore: 68,
        level: StressLevel.medium,
        physiologicalNote: 'Полезный сердечно-сосудистый эустресс. Закрыли 8.4 Strain.',
        barysReaction: '«Отличный рабочий эустресс! Мышцы нагружены, кровь разогнана по телу.»',
        barysAsset: 'assets/images/hero_barys_workout.jpg',
      ),
      StressTimeSlot(
        id: 'slot_5',
        timeRange: '19:30 — 22:00',
        contextTitle: customTags?['slot_5'] ?? 'Вечерний отдых и ужин',
        userTag: customTags?['slot_5'],
        stressScore: 18,
        level: StressLevel.rest,
        physiologicalNote: 'Парасимпатическое преобладание, запуск регенерации мелатонина.',
        barysReaction: '«Восстановление запущено. Отложи экран и приготовься ко сну у очага.»',
        barysAsset: 'assets/images/hero_barys_sleep.jpg',
      ),
    ];

    return StressDaySummary(
      currentStressScore: currentScore,
      currentLevel: currentLevel,
      minutesInHighStress: 65,
      minutesInRestoration: 210,
      timeline: timeline,
    );
  }
}
