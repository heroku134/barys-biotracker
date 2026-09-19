import 'dart:async';
import 'package:flutter/services.dart';

/// Высокоточная тактильная система CIRCA (Haptic & Acoustic Architecture).
/// Создает ощущение премиального физического устройства стоимостью $300–$500/год
/// (аналогично тактильным калибрам Leica, Bang & Olufsen и Apple Watch Ultra).
class CircaHaptics {
  /// Закрытие / дозаполнение кольца Recovery (фиксация показателя дня)
  static Future<void> ringClosure() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 65));
    await HapticFeedback.heavyImpact();
    CircaAcoustics.playMechanicalClick();
  }

  /// Прохождение промежуточной зоны кольца (33% Rose, 66% Amber)
  static Future<void> ringZoneTick() async {
    await HapticFeedback.selectionClick();
  }

  /// Старт тренировочной сессии: четкий тактильный импульс включения хронометра
  static Future<void> workoutStart() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
    CircaAcoustics.playMechanicalClick();
  }

  /// Финиш тренировки: торжественная 3-фазная резонансная последовательность
  static Future<void> workoutFinish() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 110));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 130));
    await HapticFeedback.heavyImpact();
    CircaAcoustics.playMechanicalClick();
  }

  /// Левел-ап Барыса: восходящее крещендо физической отдачи (Кадет -> Сарбаз -> Батыр)
  static Future<void> levelUp() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 110));
    await HapticFeedback.heavyImpact();
    CircaAcoustics.playMechanicalClick();
  }

  /// Выполнение микро-квеста из ежедневного чек-листа
  static Future<void> questCompleted() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 70));
    await HapticFeedback.selectionClick();
    CircaAcoustics.playMechanicalClick();
  }

  /// Экспорт шеринг-карточки (имитация затвора швейцарского/немецкого фотоаппарата)
  static Future<void> cardExport() async {
    await HapticFeedback.heavyImpact();
    CircaAcoustics.playMechanicalClick();
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
