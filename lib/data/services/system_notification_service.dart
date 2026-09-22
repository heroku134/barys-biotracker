import 'package:flutter/services.dart';
import '../../core/app_language.dart';

class SystemNotificationService {
  static const _channel = MethodChannel('sport.kalkan.biotracker/notify');

  static Future<void> requestAndSchedule({bool? ru}) async {
    try {
      await _channel.invokeMethod('requestPermission');
      await _channel.invokeMethod('scheduleDaily', {
        'id': 1101,
        'hour': 7,
        'minute': 0,
        'title': AppLocaleNotifier.pick('Восстановление готово', 'Калыбына келүү даяр', 'Recovery is ready'),
        'body': AppLocaleNotifier.pick('Откройте утро: HRV к вашей норме.', 'Таңкы HRVды караңыз.', 'Open morning HRV vs your baseline.'),
      });
      await _channel.invokeMethod('scheduleDaily', {
        'id': 1102,
        'hour': 21,
        'minute': 30,
        'title': AppLocaleNotifier.pick('Лечь до 22:30', '22:30га чейин уктаңыз', 'Lights down by 22:30'),
        'body': AppLocaleNotifier.pick('Сон сегодня важнее ещё одной сессии.', 'Бүгүнкү уйку маанилүү.', 'Sleep tonight beats another session.'),
      });
    } catch (_) {}
  }
}
