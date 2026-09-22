import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.bg,
        title: Text(AppLocaleNotifier.pick('Правила', 'Эрежелер', 'Terms'), style: AppTypography.screenTitle(palette.fg)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(AppLocaleNotifier.pick('Продукт', 'Продукт', 'Product'), style: AppTypography.bodySemibold(palette.fg)),
          const SizedBox(height: 8),
          Text(
            AppLocaleNotifier.pick(
              'КАЛКАН показывает сон, восстановление и нагрузку по данным часов СААТ-1. Это не диагноз, не лечение и не замена врачу. Цикл и беременность — дневник и ориентир нагрузки, не Flo и не медицинский сервис. Решения о тренировках принимаете вы.',
              'КАЛКАН СААТ-1 дайындары боюнча уйку, калыбына келүү жана жүктөмдү көрсөтөт. Бул диагноз эмес. Цикл менен кош бойлуулук — күндөлүк.',
              'KALKAN shows sleep, recovery and strain from SAAT-1. It is not a diagnosis or a substitute for a clinician. Cycle and pregnancy tools are a diary, not a medical service.',
            ),
            style: AppTypography.body(palette.fg).copyWith(height: 1.45),
          ),
          const SizedBox(height: 20),
          Text(AppLocaleNotifier.pick('Данные', 'Дайындар', 'Data'), style: AppTypography.bodySemibold(palette.fg)),
          const SizedBox(height: 8),
          Text(
            AppLocaleNotifier.pick(
              'На устройстве хранятся профиль, дневник и снимки дней. Если вы вошли в аккаунт, копия уходит в Firestore проекта watch-ba720: профиль, дни, код друга, цикл. Фото в облако не грузим. Выход из аккаунта не стирает локальные файлы. Удаление аккаунта в Firebase Console делает владелец проекта.',
              'Профиль жана күндөр түзмөктө жана Firestoreдо. Сүрөт булутка чыкпайт.',
              'Profile, journal and day snapshots stay on device. Signed-in copies go to Firestore project watch-ba720. Photos are not uploaded. Account deletion is done by the project owner in Firebase Console.',
            ),
            style: AppTypography.body(palette.fg).copyWith(height: 1.45),
          ),
          const SizedBox(height: 20),
          Text(AppLocaleNotifier.pick('Уведомления', 'Билдирмелер', 'Notifications'), style: AppTypography.bodySemibold(palette.fg)),
          const SizedBox(height: 8),
          Text(
            AppLocaleNotifier.pick(
              'Утро, сон, «часы сняты» и конец сессии. Токен FCM хранится у вашего uid, чтобы пуш дошёл при закрытом приложении. Каналы можно выключить в системе.',
              'Таң, уйку жана сессия. FCM токен uidде сакталат.',
              'Morning, sleep, off-wrist and session-end. An FCM token is stored on your uid so alerts can arrive when the app is closed.',
            ),
            style: AppTypography.body(palette.fg).copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}
