import 'package:flutter/services.dart';
import '../../core/app_language.dart';

class SystemNotificationService {
  static const _channel = MethodChannel('sport.kalkan.biotracker/notify');

  static const morningId = 1101;
  static const eveningId = 1102;
  static const wearId = 1103;

  static Future<void> requestAndSchedule({bool? ru}) async {
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (_) {}
  }

  static Future<void> refreshFromDay({
    required int recovery,
    required double targetMin,
    required double targetMax,
    required double strainNow,
    required int sleepMinutes,
    required double hrv,
    required double baselineHrv,
    String? yesterdayMiss,
    required bool hasNightData,
    required bool isOffWrist,
    int calibrationDay = 14,
  }) async {
    try {
      await _channel.invokeMethod('requestPermission');
      await _channel.invokeMethod('cancel', {'id': morningId});
      await _channel.invokeMethod('cancel', {'id': eveningId});
      await _channel.invokeMethod('cancel', {'id': wearId});

      if (hasNightData) {
        final title = AppLocaleNotifier.pick(
          'Recovery $recovery · сегодня ${targetMin.toStringAsFixed(0)}–${targetMax.toStringAsFixed(0)}',
          'Recovery $recovery · бүгүн ${targetMin.toStringAsFixed(0)}–${targetMax.toStringAsFixed(0)}',
          'Recovery $recovery · today ${targetMin.toStringAsFixed(0)}–${targetMax.toStringAsFixed(0)}',
        );
        var body = AppLocaleNotifier.pick(
          hrv > 0
              ? 'HRV ${hrv.toStringAsFixed(0)} при норме ${baselineHrv.toStringAsFixed(0)}.'
              : 'Откройте утро.',
          hrv > 0
              ? 'HRV ${hrv.toStringAsFixed(0)} · норма ${baselineHrv.toStringAsFixed(0)}.'
              : 'Таңды ачыңыз.',
          hrv > 0
              ? 'HRV ${hrv.toStringAsFixed(0)} vs baseline ${baselineHrv.toStringAsFixed(0)}.'
              : 'Open morning.',
        );
        if (yesterdayMiss != null && yesterdayMiss.isNotEmpty) {
          body = yesterdayMiss;
        }
        if (calibrationDay < 14) {
          body = AppLocaleNotifier.pick(
            'День $calibrationDay из 14. Цифры ещё учатся.',
            '$calibrationDay / 14 күн.',
            'Day $calibrationDay of 14. Numbers still learning.',
          );
        }
        await _schedule(morningId, 7, 0, title, body, 'morning');
      }

      final sleepOk = sleepMinutes >= 420;
      final budgetOk = strainNow >= targetMin && strainNow <= targetMax + 1;
      if (!(sleepOk && budgetOk)) {
        await _schedule(
          eveningId,
          21,
          30,
          AppLocaleNotifier.pick('Лечь до 22:30', '22:30га чейин уктаңыз', 'Lights down by 22:30'),
          yesterdayMiss ??
              AppLocaleNotifier.pick(
                'Сон сегодня важнее ещё одной сессии.',
                'Бүгүнкү уйку маанилүү.',
                'Sleep tonight beats another session.',
              ),
          'sleep',
        );
      }

      if (isOffWrist) {
        await _schedule(
          wearId,
          23,
          30,
          AppLocaleNotifier.pick('Наденьте СААТ-1', 'СААТ-1 кийиңиз', 'Put SAAT-1 on'),
          AppLocaleNotifier.pick(
            'Без ночи на запястье утро будет пустым.',
            'Түнү такта жок болсо таң бош.',
            'No night on the wrist, empty morning.',
          ),
          'wear',
        );
      }
    } catch (_) {}
  }

  static Future<void> notifyWorkoutEnd({
    required double sessionStrain,
    required double dayStrain,
    required double targetMax,
  }) async {
    try {
      await _channel.invokeMethod('showNow', {
        'id': 1201,
        'channel': 'workout',
        'title': AppLocaleNotifier.pick(
          'Сессия +${sessionStrain.toStringAsFixed(1)}',
          'Сессия +${sessionStrain.toStringAsFixed(1)}',
          'Session +${sessionStrain.toStringAsFixed(1)}',
        ),
        'body': AppLocaleNotifier.pick(
          'День ${dayStrain.toStringAsFixed(1)} из цели ${targetMax.toStringAsFixed(0)}.',
          'Күн ${dayStrain.toStringAsFixed(1)} / ${targetMax.toStringAsFixed(0)}.',
          'Day ${dayStrain.toStringAsFixed(1)} of ${targetMax.toStringAsFixed(0)}.',
        ),
      });
    } catch (_) {}
  }

  static Future<void> _schedule(
    int id,
    int hour,
    int minute,
    String title,
    String body,
    String channel,
  ) async {
    await _channel.invokeMethod('scheduleDaily', {
      'id': id,
      'hour': hour,
      'minute': minute,
      'title': title,
      'body': body,
      'channel': channel,
    });
  }
}
