# KALKAN SPORT · СААТ-1 — Архитектурный отчет и ревью кодовой базы

Данный документ подготовлен для AI-оценщика и технического ревью архитектуры приложения **KALKAN SPORT**.

---

## 1. Стек и профиль проекта

- **Фреймворк:** Flutter 3.x / Dart 3.11+
- **Архитектурный паттерн:** Clean Architecture + Feature-First (Слои: `core/`, `data/`, `domain/`, `presentation/`)
- **Стейт-менеджмент:** Reactive ValueNotifiers (`baselineNotifier`, `profileNotifier`, `xpNotifier`) + Event Streams (`telemetryStream`, `scanChannel`)
- **Целевые платформы:** iOS (Live Activities, Dynamic Island, HealthKit), Android (Health Connect, Foreground BLE Service, Home Widgets)
- **Аппаратная интеграция:** Биометрический браслет СААТ-1 (UTE BLE SDK, PPG пульсометр, 3D акселерометр, мониторинг HRV и фаз сна)

---

## 2. Структура проекта (`lib/`)

```
lib/
├── core/                               # Глобальные сервисы ядра, темы и локализация
│   ├── app_colors.dart                 # Двухслойная палитра KalkanColors (Obsidian Dark / Porcelain Light)
│   ├── app_language.dart               # Триязычная реактивная локализация (RU, KY, EN)
│   ├── app_strings.dart                # Словари и строковые константы
│   ├── app_theme.dart                  # Системное переключение тем и SystemUiOverlayStyle
│   ├── app_typography.dart             # Типографическая система Manrope + IBM Plex Mono
│   └── circa_haptics.dart              # Высокоточный тактильно-акустический слой (KalkanHaptics)
│
├── data/                               # Слой данных, нативных мостов и хранилища
│   ├── ble/
│   │   ├── ute_ble_bridge.dart         # Двусторонний MethodChannel / EventChannel мост к BLE СААТ-1
│   │   └── ble_protocol_decoder.dart   # Декодер бинарных пакетов телеметрии
│   ├── history/
│   │   └── biometrics_history_repository.dart # Долговременная история HRV, RHR и дневного стресса
│   ├── services/
│   │   ├── background_ble_sync_service.dart   # Фоновая синхронизация телеметрии
│   │   ├── cloud_sync_service.dart            # Синхронизация с облачным бэкендом
│   │   ├── health_sync_service.dart           # Двусторонний обмен HealthKit / Health Connect
│   │   ├── live_activity_service.dart         # iOS Live Activities и Dynamic Island
│   │   ├── paired_pulse.dart                  # Синхронная тактильная вибро-отдача браслета
│   │   └── system_notification_service.dart   # Умные уведомления о зонах нагрузки и стресса
│   └── storage/
│       ├── account_backup_service.dart        # Экспорт/импорт локального бэкапа атлета
│       ├── calibration_store.dart             # Реактивный источник истины 14-дневного бейзлайна
│       ├── climate_mode_store.dart            # Адаптация под горный климат Тянь-Шаня
│       ├── day_snapshot_repository.dart       # Суточные срезы готовности, сна и стресса
│       ├── onboarding_repository.dart         # Флаги онбординга и сопряжения
│       ├── partner_cycle_repository.dart      # Синхронизация женского цикла в парах
│       ├── private_league_repository.dart     # Приватные круги доверия атлетов
│       ├── user_profile_repository.dart       # Репозиторий профиля атлета
│       └── workout_repository.dart            # Локальное хранилище тренировок с GPS маршрутами
│
├── domain/                             # Слой чистой бизнес-логики и физиологических движков
│   ├── avatar/
│   │   └── avatar_manager.dart         # Геймификация маскота «Барыс-Батыр» (XP, ранги, уровни)
│   ├── intelligence/
│   │   ├── baseline_calibration_manager.dart # Алгоритм 14-дневного скользящего окна Whoop/Oura
│   │   ├── menstrual_cycle_engine.dart       # Фазы цикла, температурные сдвиги, окно фертильности
│   │   ├── readiness_engine.dart             # 3-компонентный индекс готовности (Recovery 0..100%)
│   │   ├── sleep_engine.dart                 # Оценка гипнограммы (Deep, REM, Core, Awake) и долга сна
│   │   ├── smart_daily_coach.dart            # Умный физиологический советник на день
│   │   ├── strain_engine.dart                # Кардио-нагрузка по шкале 0..21 (Whoop Strain)
│   │   └── stress_engine.dart                # Барометр стресса ЦНС в реальном времени
│   └── models/
│       ├── personal_baseline.dart      # Модель 60-дневного персонального биометрического профиля
│       ├── readiness.dart              # Результат расчета готовности и пульсовых зон
│       ├── telemetry.dart              # Модель потоковой телеметрии СААТ-1
│       ├── user_profile.dart           # Антропометрический профиль атлета (Keytel формулы)
│       └── workout_session.dart        # Модель завершенной тренировки с треком GPS и зонами ЧСС
│
└── presentation/                       # Слой представления (UI)
    ├── screens/
    │   ├── main_shell.dart             # Корневой шелл табов с реактивным мостом бейзлайна
    │   ├── dashboard_screen.dart       # Главный дашборд готовности, сна и суточного Strain
    │   ├── sport_screen.dart           # Трекинг тренировок (декомпозирован, 820 строк)
    │   ├── analytics_screen.dart       # Долговременные биомаркеры (HRV, RHR, Healthspan)
    │   ├── bio_avatar_screen.dart      # Экран маскота Барыса и утреннего синхрона
    │   ├── workout_summary_screen.dart # Итоговый отчет тренировки с картой и графиком зон
    │   ├── firmware_update_screen.dart # Честная проверка актуальности прошивки СААТ-1
    │   ├── auth_screen.dart            # Аутентификация атлета
    │   └── account_setup_screen.dart   # Первичная настройка целей и параметров тела
    └── widgets/
        ├── active_workout_panel.dart   # Модульная панель активной сессии и предстартового экрана
        ├── sport_category_selector.dart# Фильтры категорий (Улица/Зал) и горизонтальный карусель
        ├── workout_history_card.dart   # Карточка завершенной тренировки
        ├── run_route_map_widget.dart   # Карта FlutterMap с GPS трекингом
        ├── glass_card.dart             # Стеклянный контейнер с палитрой KalkanColors
        ├── circa_hypnogram.dart        # Интерактивная 4-фазная гипнограмма сна
        ├── circa_recovery_breakdown_sheet.dart # Детальный разбор факторов готовности
        └── mascot_face.dart            # Анимированное лицо маскота Барыса
```

---

## 3. Ключевые архитектурные улучшения

### 3.1. Ликвидация фантомных/синтетических данных (Honest Empty State)
- **Калибровка бейзлайна:** У нового пользователя бейзлайн строго `0/14 дней`, `sleepDebtMinutes: 0`, `recentRecoveryScores: []`. Статус: `«КАЛИБРОВКА 0/14 ДНЕЙ · ОЖИДАНИЕ ПЕРВОЙ НОЧИ»`.
- **Телеметрия до подключения:** Все поля `BleTelemetry` по умолчанию равны 0 (0 bpm, 0 шагов, 0 ккал, 0% батареи, `isConnected: false`).
- **Нативный Android (`MainActivity.kt`):** Переменные `currentBpm`, `currentSteps`, `currentCalories` стартуют со значений 0. При дисконнекте пульс сбрасывается в 0.
- **Тренировки и GPS:** Удалена симуляция фиктивных шагов (`_simulateMovementStep()`), удалены хардкодные координаты Алматы (`_seedFallbackGps()`), удалены поддельные пульсы 108..136, 128 и 72 bpm при отсутствии связи с часами. Если датчик отключен — отображается честное состояние ожидания пульса.
- **OTA и авторизация:** Удален фейковый таймер прошивки на 380 блоков; удален авто-логин под именем «Искандер» при сбое сети.

### 3.2. Реактивная синхронизация бейзлайна между всеми экранами
- В `CalibrationStore` внедрен единый `ValueNotifier<PersonalBaseline> baselineNotifier`.
- Все экраны (`MainShell`, `DashboardScreen`, `AnalyticsScreen`, `BioAvatarScreen`, `PrivateLeagueRepository`) слушают этот нотификатор. Исключены расхождения Recovery Score и калибровочных данных между соседними табами.

### 3.3. Декомпозиция монолитного экрана `SportScreen`
- Исходный размер: **1514 строк** → Текущий размер: **820 строк** (сокращение на ~46%).
- Выделены независимые переиспользуемые виджеты:
  1. [`ActiveWorkoutPanel`](lib/presentation/widgets/active_workout_panel.dart) — отображение таймера, зон ЧСС, GPS карты, расхода калорий и таймера отдыха между подходами.
  2. [`SportCategoryFilterBar` & `SportHorizontalCarousel`](lib/presentation/widgets/sport_category_selector.dart) — фильтры категорий («На улице», «В зале») и карусель видов спорта.
  3. [`WorkoutHistoryCard`](lib/presentation/widgets/workout_history_card.dart) — карточка истории тренировок с индикацией внешних источников (Apple Health, Strava).

### 3.4. Устранение дублирования моделей
- Удален дублирующий `enum HormoneCyclePhase` из `personal_baseline.dart`.
- По всей кодовой базе используется единый канонический `HormonalCyclePhase` из `user_profile.dart`.

### 3.5. Миграция ключей хранилища с обратной совместимостью
- Все ключи `circa_*` переведены на префикс `kalkan_*` (`kalkan_user_profile_v1`, `kalkan_workouts_history_v1`, `kalkan_private_league_v1`, `kalkan_partner_cycle_data`, `kalkan_app_language_code`, `kalkan_app_theme_mode`).
- Сохранена полная обратная совместимость: при чтении используется цепочка `prefs.getString('kalkan_...') ?? prefs.getString('circa_...')`.

### 3.6. Настройка вариативного шрифта Manrope
- В `pubspec.yaml` исправлено некорректное объявление шрифта Manrope со статическими весами 400/500/600 на одном ttf-файле. Шрифт объявлен как нативный вариативный шрифт, позволяющий Flutter динамически интерполировать оси плотности (FontWeight 400..800).

### 3.7. Надежная обработка ошибок BLE
- Все пустые блоки `catch (_) {}` в `ute_ble_bridge.dart` заменены информативным логированием `debugPrint`.
- Методы `isBluetoothEnabled()`, `checkPermissions()`, `requestPermissions()` при ошибке возвращают `false` (вместо `true`), что предотвращает ложное ощущение успешного подключения в UI.

---

## 4. Верификация качества и тесты

- **Статический анализ (`flutter analyze`):**
  ```
  Analyzing untitled1...
  No issues found! (ran in 3.2s)
  ```
- **Набор автоматических тестов (`flutter test`):**
  - `test/advanced_modules_test.dart` (калибровка бейзлайна, доверительный интервал, HealthSyncService, дедупликация импорта)
  - `test/precision_widgets_test.dart` (рендеринг PrecisionCard, RecoveryRing, StrainBar, SleepCard, PulseWave, CoachCard)
  - `test/workout_running_test.dart` (сериализация трека GPS, обратная совместимость репозитория, лига без фейковых друзей, привязка партнера)
  - **Результат:** 24 теста успешно пройдены (0 падений).
