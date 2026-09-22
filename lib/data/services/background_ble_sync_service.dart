import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../domain/intelligence/readiness_engine.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/intelligence/sleep_engine.dart';
import 'ios_widget_service.dart';
import '../storage/calibration_store.dart';
import '../storage/day_snapshot_repository.dart';

/// Сервис периодической фоновой синхронизации BLE-пакетов с часами СААТ-1
class BackgroundBleSyncService {
  static const String _prefKeyLastBackgroundSync = 'kalkan_bg_sync_last_timestamp';
  static const Duration _syncInterval = Duration(minutes: 15);

  static Timer? _backgroundTimer;
  static bool _isRunning = false;
  static bool get isRunning => _isRunning;

  /// Инициализирует и запускает цикл фоновой синхронизации
  static void start(UteBleBridge bridge) {
    if (_isRunning) return;
    _isRunning = true;
    debugPrint('BackgroundBleSyncService: Started periodic 15-min background sync loop');

    _backgroundTimer = Timer.periodic(_syncInterval, (timer) async {
      await performSync(bridge);
    });
  }

  /// Выполняет один цикл синхронизации накопленных биометрических данных
  static Future<bool> performSync(UteBleBridge bridge) async {
    try {
      debugPrint('BackgroundBleSyncService: Polling watch buffer...');

      // Чтение текущих телеметрических данных с часов
      final telemetry = bridge.currentTelemetry;
      final readiness = ReadinessEngine.calculate(telemetry);
      final currentStrain = telemetry.currentDayStrain > 0 ? telemetry.currentDayStrain : 0.0;
      final strainResult = StrainEngine.evaluate(
        currentStrain: currentStrain,
        recoveryZone: readiness.zone,
      );

      // Обновление нативных виджетов рабочего стола и экрана блокировки
      await IosWidgetService.updateWidgets(
        telemetry: telemetry,
        readiness: readiness,
        currentStrain: strainResult.currentStrain,
        targetStrainMax: strainResult.targetStrainMax,
        sleepScore: 0,
      );

      final prefs = await SharedPreferences.getInstance();
      await DaySnapshotRepository.recordTelemetry(
        telemetry,
        recovery: readiness.score,
        sleep: SleepEngine.calculate(telemetry: telemetry).sleepPerformanceScore,
      );
      await CalibrationStore.recordMorningSync(
        hrv: telemetry.hrv,
        rhr: telemetry.restingHeartRate,
      );
      await prefs.setString(_prefKeyLastBackgroundSync, DateTime.now().toIso8601String());

      debugPrint('BackgroundBleSyncService: Synced successfully at ${DateTime.now()}');
      return true;
    } catch (e) {
      debugPrint('BackgroundBleSyncService.performSync note: $e');
      return false;
    }
  }

  /// Останавливает фоновый опрос
  static const MethodChannel _channel = MethodChannel('sport.kalkan.biotracker/background');

  /// Просит iOS поставить BGAppRefresh / Android — ничего, если канала нет.
  static Future<void> requestNativeRefresh() async {
    try {
      await _channel.invokeMethod('scheduleRefresh');
    } catch (e) {
      debugPrint('BackgroundBleSyncService.requestNativeRefresh note: $e');
    }
  }

  static void stop() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    _isRunning = false;
  }
}
