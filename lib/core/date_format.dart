import 'app_language.dart';

class AppDates {
  static const _ruMonths = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  static const _kyMonths = [
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь',
  ];
  static const _ruWeek = [
    'понедельник',
    'вторник',
    'среда',
    'четверг',
    'пятница',
    'суббота',
    'воскресенье',
  ];
  static const _kyWeek = [
    'дүйшөмбү',
    'шейшемби',
    'шаршемби',
    'бейшемби',
    'жума',
    'ишемби',
    'жекшемби',
  ];

  static const _enMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _enWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String formatLong(DateTime date, AppLanguage language) {
    if (language == AppLanguage.kyrgyz) {
      final w = _kyWeek[date.weekday - 1];
      final m = _kyMonths[date.month - 1];
      return '$w, ${date.day}-$m';
    }
    if (language == AppLanguage.english) {
      final w = _enWeek[date.weekday - 1];
      final m = _enMonths[date.month - 1];
      return '$w, $m ${date.day}';
    }
    final w = _ruWeek[date.weekday - 1];
    final m = _ruMonths[date.month - 1];
    return '$w, ${date.day} $m';
  }
}
