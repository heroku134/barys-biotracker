import 'dart:async';
import 'package:flutter/services.dart';

/// Высокоточная тактильная система CIRCA (Haptic & Acoustic Architecture).
/// Создает ощущение премиального физического устройства стоимостью $300–$500/год
/// (аналогично тактильным калибрам Leica, Bang & Olufsen и Apple Watch Ultra).
class CircaHaptics {
  /// Закрытие / дозаполнение кольца Recovery (фиксация показателя дня)
  static Future<void> ringClosure() async {
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 65));
      await HapticFeedback.heavyImpact();
      CircaAcoustics.playMechanicalClick();
    } catch (_) {}
  }

  /// Прохождение промежуточной зоны кольца (33% Rose, 66% Amber)
  static Future<void> ringZoneTick() async {
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
      CircaAcoustics.playMechanicalClick();
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
      CircaAcoustics.playMechanicalClick();
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
      CircaAcoustics.playMechanicalClick();
    } catch (_) {}
  }

  /// Выполнение микро-квеста из ежедневного чек-листа
  static Future<void> questCompleted() async {
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 70));
      await HapticFeedback.selectionClick();
      CircaAcoustics.playMechanicalClick();
    } catch (_) {}
  }

  /// Экспорт шеринг-карточки (имитация затвора швейцарского/немецкого фотоаппарата)
  static Future<void> cardExport() async {
    try {
      await HapticFeedback.heavyImpact();
      CircaAcoustics.playMechanicalClick();
    } catch (_) {}
  }
}

/// Акустический слой тактильной обратной связи.
/// Воспроизводит мягкий механический щелчок через нативный системный аудиоканал Apple/Android.
class CircaAcoustics {
  static bool soundEnabled = true;

  /// Мягкий механический клик (Leica Shutter / Watch Bezel Click)
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
