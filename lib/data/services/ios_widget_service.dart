import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../../domain/models/readiness.dart';
import '../../domain/models/telemetry.dart';

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

  static Future<void> updateWidgets({
    required BleTelemetry telemetry,
    required ReadinessResult readiness,
    double currentStrain = 0,
    double targetStrainMax = 13.8,
    int sleepScore = 0,
    String morningLine = '',
    int calibrationDay = 14,
    bool hasNightData = false,
  }) async {
    try {
      await init();

      final sleepMins = telemetry.sleepMinutes;
      await HomeWidget.saveWidgetData<int>('recovery_score', hasNightData ? readiness.score : 0);
      await HomeWidget.saveWidgetData<String>('recovery_zone', readiness.zone.name);
      await HomeWidget.saveWidgetData<double>('current_strain', currentStrain);
      await HomeWidget.saveWidgetData<double>('target_strain_max', targetStrainMax);
      await HomeWidget.saveWidgetData<int>('heart_rate', telemetry.heartRate);
      await HomeWidget.saveWidgetData<int>('resting_heart_rate', telemetry.restingHeartRate);
      await HomeWidget.saveWidgetData<int>('hrv', telemetry.hrv.round());
      await HomeWidget.saveWidgetData<int>('sleep_hours', sleepMins ~/ 60);
      await HomeWidget.saveWidgetData<int>('sleep_minutes', sleepMins % 60);
      await HomeWidget.saveWidgetData<int>('sleep_score', sleepScore);
      await HomeWidget.saveWidgetData<String>('morning_line', morningLine);
      await HomeWidget.saveWidgetData<int>('calibration_day', calibrationDay);
      await HomeWidget.saveWidgetData<bool>('has_night_data', hasNightData);

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
