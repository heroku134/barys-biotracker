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

  static String formatLong(DateTime date, AppLanguage language) {
    final week = language == AppLanguage.kyrgyz ? _kyWeek : _ruWeek;
    final months = language == AppLanguage.kyrgyz ? _kyMonths : _ruMonths;
    final w = week[date.weekday - 1];
    final m = months[date.month - 1];
    if (language == AppLanguage.kyrgyz) {
      return '$w, ${date.day}-$m';
    }
    return '$w, ${date.day} $m';
  }
}
