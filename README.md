# КАЛКАН СПОРТ · СААТ-1

Flutter-приложение биометрии для часов без экрана (Whoop-логика: Recovery / Strain / Sleep).

## Сборка у себя

```bash
cd kalkan_sport
flutter pub get
flutter run
```

Android (реальный UTE SDK в `android/app/libs/`):

```bash
flutter build apk --release
```

iOS (Live Activity / виджеты есть, **BLE SDK часов на iOS в проекте нет**):

```bash
flutter build ios --release
```

Нужны Flutter 3.29+ / Dart 3.11, Xcode для iOS, Android SDK 34+.

## Что обновлено в этой сборке

- Светлая и тёмная тема через `KalkanColors` (светлая больше не «тёмный UI на белом фоне»).
- Шрифты вшиты: **Manrope** + **IBM Plex Mono** (кириллица, в том числе кыргызские ң/ү/ө).
- Русский и кыргызский сохранены, даты на дашборде больше не JAN/FEB.
- Новый маскот Барс: 6 состояний в `assets/images/mascot_*.jpg`.
- Спорт и цикл больше не подменяют друг друга.
- Починен leak подписки BLE в `MainShell`.
- Профиль по умолчанию не считается залогиненным.
- Парсинг `zoneMinutes` с нативного канала больше не падает на `List<dynamic>`.
- Убраны film grain и «AI pill» со сплэша.

## Маскот

| Файл | Сценарий |
|---|---|
| `mascot_normal.jpg` | обычный день |
| `mascot_charged.jpg` | высокая готовность |
| `mascot_tired.jpg` | день отдыха |
| `mascot_sleep.jpg` | ночь / отбой |
| `mascot_workout.jpg` | после нагрузки |
| `mascot_meditation.jpg` | стресс / дыхание |

Логика выбора — `lib/domain/avatar/avatar_manager.dart`.

## Честно про часы

На Android подключён UTE/Nadal SDK. С браслета стабильно приходят пульс, шаги, калории, батарея, коннект. HRV / сон / strain в UI частично считаются движками и демо-данными, пока нативный мост их не отдаёт. На iOS SDK часов нет.
