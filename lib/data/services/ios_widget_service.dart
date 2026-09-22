import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../../domain/models/readiness.dart';
import '../../domain/models/telemetry.dart';

/// Сервис синхронизации виджетов iOS (WidgetKit) и Android (AppWidget)
/// Использует общий App Group контейнер `group.watch.circle.kalkan`
class IosWidgetService {
  static const String appGroupId = 'group.watch.circle.kalkan';
  static const String iOSWidgetName = 'KalkanRecoveryWidget';

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      _initialized = true;
    } catch (e) {
      debugPrint('IosWidgetService.init error: $e');
    }
  }

  /// Синхронизация текущей биометрии с виджетами рабочего стола iOS
  static Future<void> updateWidgets({
    required BleTelemetry telemetry,
    required ReadinessResult readiness,
    double currentStrain = 0,
    double targetStrainMax = 13.8,
    int sleepScore = 88,
  }) async {
    try {
      await init();

      final sleepMins = telemetry.sleepMinutes;
      final sleepHours = sleepMins ~/ 60;
      final sleepRemainingMins = sleepMins % 60;

      // 1. Сохранение данных в общий UserDefaults App Group
      await HomeWidget.saveWidgetData<int>('recovery_score', readiness.score);
      await HomeWidget.saveWidgetData<String>('recovery_zone', readiness.zone.name);
      await HomeWidget.saveWidgetData<double>('current_strain', currentStrain);
      await HomeWidget.saveWidgetData<double>('target_strain_max', targetStrainMax);
      await HomeWidget.saveWidgetData<int>(
        'heart_rate',
        telemetry.heartRate,
      );
      await HomeWidget.saveWidgetData<int>(
        'resting_heart_rate',
        telemetry.restingHeartRate,
      );
      await HomeWidget.saveWidgetData<int>('hrv', telemetry.hrv.round());
      await HomeWidget.saveWidgetData<int>('sleep_hours', sleepHours);
      await HomeWidget.saveWidgetData<int>('sleep_minutes', sleepRemainingMins);
      await HomeWidget.saveWidgetData<int>('sleep_score', sleepScore);

      // 2. Отправка триггера перезагрузки таймлайна WidgetKit на iOS
      await HomeWidget.updateWidget(
        name: 'KalkanHomeWidgetProvider',
        androidName: 'KalkanHomeWidgetProvider',
        iOSName: iOSWidgetName,
      );
    } catch (e) {
      debugPrint('IosWidgetService.updateWidgets note: $e');
    }
  }
}
