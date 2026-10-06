import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../../domain/models/readiness.dart';
import '../../domain/models/telemetry.dart';

class IosWidgetService {
  static const String appGroupId = 'group.watch.circle.kalkan';
  static const String iOSWidgetName = 'KalkanRecoveryWidget';

  /// App Group entitlement is configured in Runner.entitlements and KalkanWidget.entitlements.
  /// Wrapped in defensive try/catch to protect development environments without App Group profiles.
  static const bool hasAppGroupEntitlement = true;

  static bool _initialized = false;
  static bool _hasAppGroupError = false;

  static bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> init() async {
    // On iOS without App Group capability, NEVER touch HomeWidget to avoid native crash
    if (_isIos && !hasAppGroupEntitlement) {
      debugPrint('IosWidgetService.init: Skipped on iOS (no paid App Group profile)');
      return;
    }
    if (_initialized || _hasAppGroupError) return;
    try {
      if (_isIos) {
        await HomeWidget.setAppGroupId(appGroupId);
      }
      _initialized = true;
    } catch (e) {
      _hasAppGroupError = true;
      debugPrint('IosWidgetService.init note: $e');
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
    // On iOS without App Group capability, NEVER touch HomeWidget to avoid native crash
    if (_isIos && !hasAppGroupEntitlement) return;
    if (_hasAppGroupError) return;
    try {
      await init();
      if (_isIos && !_initialized) return;

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
        qualifiedAndroidName: 'com.yc.nadalsdk.barys_biotracker.KalkanHomeWidgetProvider',
        iOSName: iOSWidgetName,
      );
    } catch (e) {
      debugPrint('IosWidgetService.updateWidgets note: $e');
    }
  }
}
