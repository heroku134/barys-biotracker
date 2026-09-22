import '../../core/app_language.dart';
import '../../data/storage/climate_mode_store.dart';

class DayCopy {
  static String morning({
    required int sleepScore,
    required double tMin,
    required double tMax,
    String? miss,
    ClimateMode climate = ClimateMode.normal,
  }) {
    final range = '${tMin.toStringAsFixed(0)}–${tMax.toStringAsFixed(1)}';
    final hour = DateTime.now().hour;
    String core;
    if (hour >= 21) {
      core = AppLocaleNotifier.pick(
        'Пора снижать свет и лечь до 22:30.',
        'Жарыкты басып, 22:30га чейин уктаңыз.',
        'Dim the lights and sleep by 22:30.',
      );
    } else if (sleepScore < 70) {
      core = AppLocaleNotifier.pick(
        'Сегодня $range. Вчера сон не добрали — без тяжёлой работы.',
        'Бүгүн $range. Кечээки уйку жеткен жок.',
        'Today $range. Sleep ran short — keep the work easy.',
      );
    } else {
      core = AppLocaleNotifier.pick(
        'Сегодня $range.',
        'Бүгүн $range.',
        'Today $range.',
      );
    }
    if (miss != null && miss.isNotEmpty) {
      return '$core $miss';
    }
    if (climate == ClimateMode.altitude) {
      return '$core ${AppLocaleNotifier.pick('Горы: бюджет ниже.', 'Тоо: бюджет төмөн.', 'Altitude: budget is lower.')}';
    }
    if (climate == ClimateMode.heat) {
      return '$core ${AppLocaleNotifier.pick('Жара: бюджет ниже.', 'Ысык: бюджет төмөн.', 'Heat: budget is lower.')}';
    }
    return core;
  }
}
