import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Flutter-сервис для управления iOS Live Activities & Dynamic Island
class LiveActivityService {
  static const MethodChannel _channel = MethodChannel('sport.kalkan.biotracker/live_activity');

  static bool _isLiveActivityActive = false;
  static bool get isLiveActivityActive => _isLiveActivityActive;

  /// Запускает Live Activity на Dynamic Island и экране блокировки iOS
  static Future<bool> startWorkoutActivity({
    required String workoutName,
    required String workoutType,
    required int initialHeartRate,
    required int heartRateZone,
    required double currentStrain,
    required int activeCalories,
  }) async {
    if (!Platform.isIOS) return false;

    try {
      final success = await _channel.invokeMethod<bool>('startWorkoutActivity', {
        'workoutName': workoutName,
        'workoutType': workoutType,
        'heartRate': initialHeartRate,
        'heartRateZone': heartRateZone,
        'currentStrain': currentStrain,
        'activeCalories': activeCalories,
        'startTime': DateTime.now().millisecondsSinceEpoch,
      });

      _isLiveActivityActive = success ?? false;
      return _isLiveActivityActive;
    } catch (e) {
      debugPrint('LiveActivityService.startWorkoutActivity note: $e');
      return false;
    }
  }

  /// Обновляет пульс, зону, нагрузку и калории во время активной тренировки
  static Future<void> updateWorkoutActivity({
    required int heartRate,
    required int heartRateZone,
    required double currentStrain,
    required int activeCalories,
    required String workoutType,
  }) async {
    if (!Platform.isIOS || !_isLiveActivityActive) return;

    try {
      await _channel.invokeMethod('updateWorkoutActivity', {
        'heartRate': heartRate,
        'heartRateZone': heartRateZone,
        'currentStrain': currentStrain,
        'activeCalories': activeCalories,
        'workoutType': workoutType,
      });
    } catch (e) {
      debugPrint('LiveActivityService.updateWorkoutActivity note: $e');
    }
  }

  /// Завершает Live Activity при остановке тренировки
  static Future<void> endWorkoutActivity() async {
    if (!Platform.isIOS || !_isLiveActivityActive) return;

    try {
      await _channel.invokeMethod('endWorkoutActivity');
      _isLiveActivityActive = false;
    } catch (e) {
      debugPrint('LiveActivityService.endWorkoutActivity note: $e');
    }
  }
}
