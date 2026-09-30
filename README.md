# КАЛКАН СПОРТ · СААТ-1

Flutter-приложение биометрии для часов без экрана (Whoop-логика: Recovery / Strain / Sleep).

## Сборка у себя

```bash
flutter pub get
flutter run
```

### Android (нативный UTE/Nadal SDK в `android/app/libs/`):

```bash
flutter build apk --release
```

### iOS (нативный UTE SDK v1.3.1 в `ios/Frameworks/` + Live Activity + Widgets):

```bash
cd ios
pod install
cd ..
flutter build ipa --release
```

> **Важно для iOS**: Нативный SDK часов `UTEBluetoothRYApi.framework` (версия 1.3.1) поставляется в `ios/Frameworks/` и подключён через локальный podspec `ios/UTEBluetoothRYApi.podspec`. Перед сборкой обязательно выполните `pod install` в папке `ios/`, чтобы Xcode скомпилировал нативный UTE-мост с прямым протоколом часов, а не запасной CoreBluetooth-сканер.

Нужны Flutter 3.29+ / Dart 3.11, Xcode 14+ для iOS, Android SDK 34+.

## Что обновлено в этой сборке

- **Нативный BLE SDK на обеих платформах**: Android (UTE AAR) и iOS (`UTEBluetoothRYApi.framework` v1.3.1) с поддержкой прямого считывания пульса, шагов, калорий, батареи, сна и вариабельности (HRV).
- **Безопасность и приватность данных**:
  - `UserProfile.fromJson` по умолчанию не авторизует профиль без подтверждения (`isAuthenticated: false`).
  - Полноценный сброс пароля ("Забыли пароль?") без искажения пробелов в паролях.
  - Криптографически стойкие инвайт-коды (`SecureInviteGenerator`, пространство $30^8 > 6.5 \cdot 10^{11}$).
  - Разделение типов инвайтов (`friend` vs `cycle`) с защитой от кросс-использования.
  - Жесткие правила безопасности Cloud Firestore (`firestore.rules`) с защитой PII и доступом к репродуктивным данным только по проверенной цепочке инвайта.
  - Внутриприложенное удаление аккаунта и данных (App Store Guideline 5.1.1(v)) в «Профиле».
  - Разрешения HealthKit (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`) в `Info.plist` и Health Connect в `AndroidManifest.xml`.
- **UI и дизайн-система KalkanUi**:
  - Единая сетка (14/8/4/20/12/16/44), плоские поверхности `KalkanCard` с hairline border, отсутствие декоративного неонового блюра.
  - Честные пустые состояния (без фейковых "Live" точек у вымышленных друзей, без 380-блочного фейкового OTA, серая полоса гипнограммы при отсутствии ночных фаз).
  - Спокойная тактильность: одиночный `selectionClick`, тяжелая виброотдача только на старте/финише тренировок.
  - Защищённый деструктивный паттерн выхода из аккаунта и удаления данных.
- Светлая и тёмная тема через `KalkanColors`.
- Шрифты вшиты: **Manrope** + **IBM Plex Mono** (кириллица, в том числе кыргызские ң/ү/ө).
- Трёхъязычный интерфейс (Русский, Кыргызча, English).
- Маскот Барс: 6 состояний в `assets/images/mascot_*.jpg`.

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

## Подключение часов

- **Android**: UTE/Nadal SDK через `android/app/libs/`. Прямое чтение датчиков.
- **iOS**: UTE SDK v1.3.1 (`UTEBluetoothRYApi.framework`) через CocoaPods. Прямое чтение пульса, шагов, сна, HRV, RHR и батареи.
- При отсутствии часов приложение честно отображает нулевые/пустые состояния без синтетических подставок.
