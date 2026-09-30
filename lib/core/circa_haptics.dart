import 'dart:async';
import 'package:flutter/services.dart';

/// Тактильная система KALKAN SPORT.
///
/// Канонические правила тактильности:
/// - Обычный выбор элемента (таб, чип, язык, свитч): ровно один `HapticFeedback.selectionClick()`, без звука.
/// - Подтверждение / сохранение: лёгкий `HapticFeedback.lightImpact()`.
/// - Тяжёлые тактильные события (старт/финиш тренировки, закрытие кольца Recovery): выделенные составные импульсы.
class KalkanHaptics {
  /// Закрытие / дозаполнение кольца Recovery (фиксация показателя дня)
  static Future<void> ringClosure() async {
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 65));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Успешное сохранение настроек или подтверждение действия (лёгкий отклик без сотрясения)
  static Future<void> success() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Прохождение промежуточной зоны кольца (33% Rose, 66% Amber)
  static Future<void> ringZoneTick() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Выбор / переключение элемента (чип, таб, язык) — ровно один selectionClick без звука
  static Future<void> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Старт тренировочной сессии: четкий тактильный импульс включения хронометра
  static Future<void> workoutStart() async {
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Финиш тренировки: торжественная 3-фазная резонансная последовательность
  static Future<void> workoutFinish() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 110));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 130));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Левел-ап Барыса: восходящее крещендо физической отдачи (Кадет -> Сарбаз -> Батыр)
  static Future<void> levelUp() async {
    try {
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 90));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 110));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Выполнение микро-квеста из ежедневного чек-листа
  static Future<void> questCompleted() async {
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 70));
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Экспорт шеринг-карточки
  static Future<void> cardExport() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Предупреждение / экстренное действие
  static Future<void> heavyAlert() async {
    try {
      await HapticFeedback.heavyImpact();
      KalkanAcoustics.playAlertSound();
    } catch (_) {}
  }

  /// Открытие всплывающего модального окна / шита
  static Future<void> sheetOpen() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}

/// Акустический слой тактильной обратной связи.
/// По умолчанию отключён (soundEnabled = false), чтобы не создавать назойливых
/// системных щелчков на Android/iOS при повседневном взаимодействии с интерфейсом.
class KalkanAcoustics {
  static bool soundEnabled = false;

  /// Системный механический клик
  static void playMechanicalClick() {
    if (!soundEnabled) return;
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Акустический сигнал тревоги / предупреждения
  static void playAlertSound() {
    if (!soundEnabled) return;
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }
}

/// Алиасы для обратной совместимости
typedef CircaHaptics = KalkanHaptics;
typedef CircaAcoustics = KalkanAcoustics;
