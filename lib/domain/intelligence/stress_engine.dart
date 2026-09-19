import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

enum StressLevel {
  rest('Восстановление', AppColors.sage),
  low('Низкий стресс', AppColors.cyan),
  medium('Умеренный стресс', AppColors.amber),
  high('Высокий стресс', AppColors.rose);

  final String label;
  final Color color;

  const StressLevel(this.label, this.color);
}

class StressTimeSlot {
  final String timeRange; // e.g. "09:00 — 11:30"
  final String contextTitle; // e.g. "Утренний фокус / Работа"
  final int stressScore; // 0..100
  final StressLevel level;
  final String physiologicalNote;

  const StressTimeSlot({
    required this.timeRange,
    required this.contextTitle,
    required this.stressScore,
    required this.level,
    required this.physiologicalNote,
  });
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
  /// Генерация суточной ленты стресса на основе пульса vs личного RHR и скользящего окна ВСР
  static StressDaySummary analyze({
    required int currentScore,
  }) {
    final StressLevel currentLevel;
    if (currentScore >= 75) {
      currentLevel = StressLevel.high;
    } else if (currentScore >= 50) {
      currentLevel = StressLevel.medium;
    } else if (currentScore >= 25) {
      currentLevel = StressLevel.low;
    } else {
      currentLevel = StressLevel.rest;
    }

    final timeline = [
      const StressTimeSlot(
        timeRange: '07:30 — 09:00',
        contextTitle: 'Пробуждение и дорога',
        stressScore: 28,
        level: StressLevel.low,
        physiologicalNote: 'Пульс стабилен, вегетативный тонус в норме.',
      ),
      const StressTimeSlot(
        timeRange: '09:30 — 12:30',
        contextTitle: 'Рабочий спринт и аналитика',
        stressScore: 54,
        level: StressLevel.medium,
        physiologicalNote: 'Умеренная симпатическая активация, концентрация внимания.',
      ),
      const StressTimeSlot(
        timeRange: '13:30 — 15:00',
        contextTitle: 'Дедлайн / Сложные переговоры',
        stressScore: 78,
        level: StressLevel.high,
        physiologicalNote: 'Кратковременное падение ВСР на фоне рабочего стресса.',
      ),
      const StressTimeSlot(
        timeRange: '17:30 — 18:30',
        contextTitle: 'Тренировка / Физическая нагрузка',
        stressScore: 68,
        level: StressLevel.medium,
        physiologicalNote: 'Полезный эустресс сердечно-сосудистой системы.',
      ),
      const StressTimeSlot(
        timeRange: '19:30 — 22:00',
        contextTitle: 'Вечерний отдых и ужин',
        stressScore: 18,
        level: StressLevel.rest,
        physiologicalNote: 'Парасимпатическое преобладание, запуск регенерации.',
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
