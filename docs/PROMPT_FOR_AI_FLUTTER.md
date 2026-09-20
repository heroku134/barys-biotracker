# 🚀 MASTER-PROMPT ДЛЯ ИИ-РАЗРАБОТЧИКА (FLUTTER / DART)
## Проект: Кроссплатформенное приложение биометрического мониторинга с персонажем «Барыс-Батыр» (iOS & Android)

> **Кем ты являешься:** Ты — Senior Flutter Architect и Lead Mobile Engineer с глубоким опытом в Clean Architecture, CustomPainter-анимациях, Bluetooth Low Energy (BLE) и интеграции нативных SDK (Android AAR + iOS Frameworks).
>
> **Твоя задача:** Написать полноценный кроссплатформенный Flutter-проект (Android и iOS), полностью портировав бизнес-логику, математические формулы, геймификацию с персонажем Барыс-Батыром и нативный BLE-стек из предоставленного эталонного Android-проекта.

---

## 📁 1. Содержимое предоставленного пакета `flutter_pack`

В этой папке подготовлены все исходные материалы, чтобы тебе не пришлось ничего придумывать с нуля:
```text
flutter_pack/
├── assets/
│   ├── hero_barys_charged.jpg   # Картинка Барыс-Батыра в бодром/заряженном состоянии (мышцы, шапан)
│   ├── hero_barys_tired.jpg     # Картинка Барыс-Батыра в уставшем состоянии (пот, опущенные плечи, Zzz)
│   ├── ic_avatar_hero.xml       # Векторная иконка героя
│   └── colors.xml               # Фирменная палитра (Midnight Obsidian, Sapphire Glass, Gold, Emerald)
│
├── core_sources/
│   ├── avatar/
│   │   ├── AvatarManager.kt     # Логика уровней (1-20), XP, квестов, расчет состояния (Charged/Tired)
│   │   ├── BioAvatarView.kt     # Кастомный Canvas-рендер: кинематика дыхания, пульсирующий реактор, Zzz/искры
│   │   └── BioAvatarActivity.kt # Экран персонажа, статы (Выносливость, Сила, Фокус), кнопка тренировки
│   ├── intelligence/
│   │   ├── ReadinessEngine.kt   # Формула индекса готовности (Readiness 0-100%, HRV, пульс, сон, нагрузка)
│   │   └── SmartDailyCoach.kt   # ИИ-коуч с советами на русском языке по биометрии
│   ├── views/
│   │   ├── CircaReadinessRingView.kt # Кольцо готовности в стиле Oura / Whoop
│   │   └── LivePulseWaveView.kt      # Неоновая ЭКГ-волна пульса в реальном времени
│   ├── utils/AudioHapticHelper.kt    # Тактильный и звуковой отклик люкс-класса
│   ├── telemetry/TelemetryHub.kt     # Центральный хаб потока данных с часов
│   ├── services/BleSyncService.java  # Фоновый сервис синхронизации
│   └── activity_ble_device.xml       # Главный дашборд с приподнятой круглой кнопкой аватара в центре
│
└── libs/
    ├── android/uteWatchSdk_Android_v1.3.9.aar  # Нативный Android SDK для чипов UTE / Nadal / Actions
    └── ios/
        ├── Readme.txt
        └── UTEBluetoothRYApi.framework        # Нативный iOS SDK (CoreBluetooth обёртка от производителя)
```

---

## 🎨 2. Визуальный стиль и дизайн-система

Приложение выполнено в стилистике **Luxury Sapphire / Dark Glassmorphism** (уровень Whoop 4.0, Oura Ring Gen 3, Porsche Design):
* **Фон:** Глубокий обсидиан `0xFF0A0D14` с мягким градиентом в полночный синий `0xFF0F172A`.
* **Карточки:** Сапфировое матовое стекло `0x261E293B` с тонкой каймой `0x33475569` и эффектом блюра.
* **Акценты:**
  * Золото (премиум, уровень персонажа): `0xFFF59E0B` / `0xFFD97706`
  * Неоновый изумруд (восстановление, готовность > 85%): `0xFF10B981`
  * Электрический циановый (шаги, фазы сна): `0xFF06B6D4`
  * Пульсирующий красный (сердцебиение, био-реактор): `0xFFEF4444`
* **Нижняя навигация:**
  * Полупрозрачный стеклянный бар с 4 вкладками: «Дашборд», «Анализ», «Спорт», «Профиль».
  * **В центре — приподнятая круглая золотая кнопка (Floating Avatar Button, 64x64 dp)** с миниатюрой Барыса и светящимся индикатором текущего статуса (зеленый/красный ободок). Нажатие открывает экран героя.

---

## 🐅 3. Главный герой: «Барыс-Батыр» (Архитектура маскота)

### 3.1. Два динамических визуальных состояния
Герой динамически меняет внешний вид в зависимости от физиологического восстановления пользователя (`readinessScore` из `ReadinessEngine`):
1. **`CHARGED` (Бодрый / Заряженный)** — при готовности $\ge 75\%$:
   * Используется изображение `assets/hero_barys_charged.jpg`.
   * Вокруг персонажа парят золотые частицы энергии (светящиеся искры).
   * Персонаж дышит мощно и уверенно.
   * Текст статуса: «Қар Барысы: Бодр и заряжен на подвиги! ⚡».
2. **`TIRED` (Уставший / Спящий)** — при готовности $< 50\%$:
   * Используется изображение `assets/hero_barys_tired.jpg`.
   * Вокруг персонажа парят полупрозрачные пузыри с буквой «Zzz».
   * Дыхание более медленное и глубокое.
   * Текст статуса: «Батыр восстанавливает силы... Нужен сон! 💤».
3. **`NORMAL` (Обычный)** — при $50\% \le \text{readiness} < 75\%$:
   * Спокойное устойчивое состояние.

### 3.2. Кинематика дыхания и Био-реактор в груди (`CustomPainter`)
В Flutter реализуй кастомный виджет `BioAvatarWidget`, используя `AnimationController` и `CustomPainter`:
1. **Синусоидальное дыхание:**
   $$\text{scaleY} = 1.0 + 0.035 \times \sin(\text{breathTime})$$
   $$\text{scaleX} = 1.0 - 0.015 \times \sin(\text{breathTime})$$
   (Период: 4.5 секунды для бодрого, 6.0 секунд для уставшего).
2. **Пульсирующий био-реактор (Chest Core Reactor):**
   * Расположен в центре груди персонажа.
   * Пульсирует в такт **реальному пульсу (BPM)** с браслета:
     $$\text{periodMs} = \frac{60000}{\text{bpm}}$$
   * При каждом ударе пульса кольцо реактора вспыхивает радиальным градиентом от `0xFFFF3B30` к прозрачному с расширением радиуса (spring expand & fade).
3. **Интерактивный Spring Bounce:**
   * При тапе по персонажу виджет пружинит (масштаб сжимается до 0.94 и плавно возвращается через кривую `Curves.elasticOut`).
   * Воспроизводится легкий тактильный отклик `HapticFeedback.mediumImpact()`.

### 3.3. Движок прогрессии (`AvatarManager` -> `avatar_provider.dart`)
* **20 уровней персонажа:**
  1. «Ирбис-Кадет» (0 XP)
  2. «Степной Следопыт» (500 XP)
  3. «Горный Страж» (1,200 XP)
  ...
  20. «Легендарный Қар Барысы» (50,000 XP)
* **Характеристики героя:**
  * **Выносливость (Endurance):** качается шагами ($+1$ за каждые 2,000 шагов).
  * **Сила (Power):** качается тренировками и тапами кнопки прокачки.
  * **Фокус (Focus):** качается качеством сна ($+1$ за каждый час глубокого сна).
* **Ежедневные квесты:**
  * «Шаги батыра» (10,000 шагов) $\to +150$ XP
  * «Богатырский сон» ($\ge 7.5$ часов) $\to +200$ XP
  * «Пик готовности» ($\text{Readiness} \ge 85\%$) $\to +180$ XP
* **Кнопка тренировки (Тренировать Батыра):**
  * Добавляет $+25$ XP за нажатие (с кулдауном или приливом энергии от шагов).
  * При левелапе срабатывает `HapticFeedback.heavyImpact()` и открывается диалог поздравления.

---

## 🧮 4. Биометрический движок готовности (`ReadinessEngine` на чистом Dart)

Портируй класс `ReadinessEngine.kt` в Dart:
```dart
class ReadinessResult {
  final int score;               // 0 .. 100
  final ReadinessCategory category; // optimal, good, recovery, exhausted
  final int hrvScore;
  final int sleepScore;
  final int rhrScore;
  final int strainScore;
  final String advice;

  const ReadinessResult({
    required this.score,
    required this.category,
    required this.hrvScore,
    required this.sleepScore,
    required this.rhrScore,
    required this.strainScore,
    required this.advice,
  });
}
```

**Формула расчета Score:**
$$\text{Readiness} = (\text{hrvScore} \times 0.35) + (\text{sleepScore} \times 0.30) + (\text{rhrScore} \times 0.20) + (\text{strainScore} \times 0.15)$$
* $\text{hrvScore}$: нормализованное отклонение текущего HRV (мс) от индивидуального базового уровня.
* $\text{sleepScore}$: отношение продолжительности и глубоких фаз сна к норме 8 часов.
* $\text{rhrScore}$: показатель пульса покоя (чем ниже пульс покоя относительно нормы, тем выше балл).
* $\text{strainScore}$: обратная величина от дневной нагрузки по шагам/калориям.

---

## 📡 5. Архитектура гибридного BLE-плагина (MethodChannel & EventChannel)

Для работы с браслетом создается нативный мост `UteBlePlugin`:

```text
[Flutter Dart UI & Logic]
      ↕ MethodChannel ('com.nadal.ble/methods')  <- Команды: scan(), connect(), sync()
      ↕ EventChannel  ('com.nadal.ble/telemetry') <- Поток: BPM, шаги, батарея, сон
      ---------------------------------------------------------------------------------
      ├── Android: UteBlePlugin.kt -> com.yc.nadalsdk.aar (OnBleScanListener, etc.)
      └── iOS:     UteBlePlugin.swift -> UTEBluetoothRYApi.framework (UTEBluetoothRYApiDelegate)
```

### 5.1. Dart-интерфейс (`lib/data/ble/ute_ble_service.dart`)
```dart
abstract class UteBleService {
  Stream<BleTelemetry> get telemetryStream;
  Stream<BleConnectionStatus> get statusStream;

  Future<void> startScan();
  Future<void> stopScan();
  Future<bool> connect(String deviceAddress);
  Future<void> disconnect();
  Future<void> triggerHeartRateMeasurement();
}

class BleTelemetry {
  final int heartRate;       // BPM
  final int steps;           // текущие шаги
  final int calories;        // ккал
  final int batteryLevel;    // 0 - 100%
  final double hrv;          // ms
  final Duration sleepTime;  // длительность сна
  final DateTime timestamp;
}
```

### 5.2. Реализация Android (`android/src/main/kotlin/.../UteBlePlugin.kt`)
* Подключает `uteWatchSdk_Android_v1.3.9.aar`.
* В `onAttachedToEngine` регистрирует `MethodChannel` и `EventChannel`.
* Принимает вызовы `startScan`, `connect`.
* Слушатель `OnHeartRateListener` и `OnStepListener` пересылает события в `eventSink.success(map)`.

### 5.3. Реализация iOS (`ios/Classes/UteBlePlugin.swift`)
* Линкует `UTEBluetoothRYApi.framework`.
* Подписывается на делегаты `UTEBluetoothRYApiDelegate`.
* Отправляет телеметрию в тот же `EventChannel`.

---

## 📱 6. Структура экранов Flutter-приложения

1. **DashboardScreen (Главный экран):**
   * Верхний статус-бар: имя подключенного устройства, заряд батареи (с зеленым бейджем), статус BLE.
   * **CircaReadinessRing:** Большое неоновое кольцо готовности (например, 88% Оптимально) с подписью коуча.
   * **LivePulseCard:** Живой пульс (например, 72 BPM) с анимированной неоновой ЭКГ-волной `LivePulseWaveWidget`.
   * **MiniHeroCard:** Карточка Барыса («Ур. 5 Горный Страж», мини-аватар с дыханием, кнопка «Открыть героя»).
   * **MetricGrid:** Сетка 2x2: Шаги, Сон, Калории, HRV.
2. **BioAvatarScreen (Экран персонажа):**
   * Большой интерактивный холст с Барыс-Батыром (заряженный или уставший).
   * Полоса опыта XP и текущий ранг на казахском/русском.
   * Три полосы прокачки: Выносливость, Сила, Фокус.
   * Список ежедневных квестов с чекбоксами прогресса.
   * **Выделенная кнопка внизу:** «Тренировать Батыра (+25 XP)» с анимацией нажатия и виброоткликом.
3. **AnalyticsScreen:**
   * График пульса за день (почасовой).
   * Гипнограмма сна (фазы: Глубокий, Легкий, REM, Пробуждения).

---

## 🛠️ 7. Рекомендуемый стек библиотек `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1   # Реактивное управление состоянием
  shared_preferences: ^2.3.2 # Сохранение уровня XP и квестов
  flutter_animate: ^4.5.0    # Плавные микроанимации интерфейса
  google_fonts: ^6.2.1       # Шрифты Montserrat / Inter
  vibration: ^2.0.1          # Тактильный виброотклик
  fl_chart: ^0.69.0          # Красивые неоновые графики

flutter:
  assets:
    - assets/hero_barys_charged.jpg
    - assets/hero_barys_tired.jpg
```

---

## 🎯 8. Пошаговый план реализации для тебя (ИИ):

1. **Шаг 1 (Константы и Модели):** Создай тему приложения, цвета из `colors.xml`, модели `ReadinessResult`, `AvatarState`, `BleTelemetry`.
2. **Шаг 2 (Математика):** Перенеси `ReadinessEngine` и `AvatarManager` на чистый Dart. Напиши юнит-тесты формул.
3. **Шаг 3 (Кастомная графика Барыса):** Реализуй `BioAvatarWidget` с дыханием, частицами и пульсирующим реактором.
4. **Шаг 4 (UI Дашборда):** Собери `DashboardScreen` и `BioAvatarScreen` со стеклянными карточками и кольцом готовности.
5. **Шаг 5 (BLE Мост):** Напиши нативную часть для Android (`UteBlePlugin.kt`) и iOS (`UteBlePlugin.swift`), свяжи с `ute_ble_service.dart`.
6. **Шаг 6 (Сборка и проверка):** Запусти `flutter run` на симуляторе/реальном девайсе.

Приступай к реализации, следуя этим инструкциям шаг за шагом!
