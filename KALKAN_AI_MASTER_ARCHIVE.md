# KALKAN SPORT (СААТ-1) · ПОЛНЫЙ АРХИВ ЛОГИКИ И ДИЗАЙНА ДЛЯ ИИ
**Версия: 3.0-PRODUCTION · Сентябрь 2026**

> Этот файл предназначен для передачи полного контекста проекта любой ИИ-модели (ChatGPT, Claude, Gemini, Grok и др.). Содержит ВСЕ: архитектуру, математику, BLE-протоколы, дизайн-систему, карту файлов и правила разработки.

---

## 1. КАРТА ПРОЕКТА (FILE MAP)

```
barys_biotracker/
├── lib/
│   ├── main.dart                                      # Точка входа: Firebase, BLE, Splash
│   ├── core/                                          # ДИЗАЙН-СИСТЕМА
│   │   ├── app_colors.dart                            # 3-цветная палитра (Sage/Amber/Rose) + обсидиановые фоны
│   │   ├── app_language.dart                          # Билингвальная система (RU/KG) с ValueNotifier
│   │   ├── app_strings.dart                           # ~400 строк локализации (2 языка, ноль эмодзи)
│   │   ├── app_theme.dart                             # Dark/Light темы, SF Pro Display/Inter/Roboto
│   │   ├── app_typography.dart                        # Табулярные цифры, FontFeature.tabularFigures()
│   │   └── circa_haptics.dart                         # Тактильная обратная связь (Light/Medium/Heavy/Selection)
│   │
│   ├── domain/                                        # БИЗНЕС-ЛОГИКА И ФИЗИОЛОГИЯ
│   │   ├── intelligence/                              # МАТЕМАТИЧЕСКИЕ ДВИЖКИ
│   │   │   ├── readiness_engine.dart                  # Recovery Score: 0.35·HRV + 0.25·RHR + 0.20·Sleep + 0.10·RR + 0.10·Temp
│   │   │   ├── strain_engine.dart                     # TRIMP-нагрузка (0.0–21.0), пульсовые зоны Z1–Z5
│   │   │   ├── sleep_engine.dart                      # 4-факторный Sleep Performance, гипнограмма, Sleep Planner
│   │   │   ├── stress_engine.dart                     # Суточная хроника стресса, 15-мин слоты, контекстные теги
│   │   │   ├── menstrual_cycle_engine.dart            # 4-фазный гормональный цикл, термический сдвиг СААТ-1
│   │   │   ├── healthspan_engine.dart                 # Биологический возраст: VO2max + RHR тренд + сон
│   │   │   └── smart_daily_coach.dart                 # ИИ-тренер: утренний брифинг на основе Recovery
│   │   │
│   │   ├── models/                                    # МОДЕЛИ ДАННЫХ
│   │   │   ├── telemetry.dart                         # BleTelemetry: 25+ полей (HR, HRV, сон, стресс, нагрузка)
│   │   │   ├── user_profile.dart                      # Профиль: пол, цикл, антропометрия, Gender enum
│   │   │   ├── personal_baseline.dart                 # 60-дневный скользящий базис (medianHRV, meanRHR, sleepNeed)
│   │   │   ├── readiness.dart                         # ReadinessResult + RecoveryZone enum
│   │   │   ├── partner_cycle_data.dart                # Данные цикла партнёра + рекомендации «Как поддержать»
│   │   │   ├── private_league.dart                    # PrivateLeague модель (5 слотов, рейтинг)
│   │   │   └── workout_session.dart                   # Тренировочная сессия (GPS, HR-зоны, калории)
│   │   │
│   │   └── avatar/
│   │       └── avatar_manager.dart                    # Управление аватарами Барыса (тотем, свечение, анимация)
│   │
│   ├── data/                                          # ДАННЫЕ И СВЯЗЬ
│   │   ├── ble/
│   │   │   ├── ute_ble_bridge.dart                    # BLE-мост: MethodChannel + EventChannel → _realTelemetry
│   │   │   └── ble_simulator.dart                     # Симулятор телеметрии (покой, ходьба, бег, сон, стресс)
│   │   │
│   │   ├── storage/
│   │   │   ├── user_profile_repository.dart           # SharedPreferences → UserProfile
│   │   │   ├── partner_cycle_repository.dart          # Хранение и синхронизация данных партнёра
│   │   │   ├── private_league_repository.dart         # Хранение приватной лиги (5 друзей)
│   │   │   └── workout_repository.dart                # Хранение тренировочных сессий
│   │   │
│   │   └── history/
│   │       └── biometrics_history_repository.dart     # 30-дневная история: HR, HRV, RHR, сон, нагрузка, стресс
│   │
│   └── presentation/                                  # UI-СЛОЙ
│       ├── screens/                                   # ЭКРАНЫ (12 файлов)
│       │   ├── splash_screen.dart                     # Сплеш с пульсирующим логотипом
│       │   ├── auth_screen.dart                       # Авторизация (лого + имя + язык, без выбора пола)
│       │   ├── main_shell.dart                        # Нижний таб-бар (5 вкладок, гендер-адаптивный 4-й таб)
│       │   ├── dashboard_screen.dart                  # Главный экран: Recovery, Strain, Sleep, Partner карточки
│       │   ├── sport_screen.dart                      # Спортивный экран: тренировки, GPS-треки, зоны HR
│       │   ├── bio_avatar_screen.dart                 # Био-аватар Барыса: тотем, квесты, народная мудрость
│       │   ├── menstrual_cycle_screen.dart            # Менструальный цикл: 28-дневная орбита, дневник, партнёр
│       │   ├── private_league_screen.dart             # Приватная лига (5 слотов, импульс силы)
│       │   ├── profile_screen.dart                    # Профиль: паспорт атлета, BLE-настройки, язык, «ГРОЗА»
│       │   ├── analytics_screen.dart                  # Аналитика: 7/30-дневные тренды, графики
│       │   ├── device_pair_screen.dart                # Сопряжение часов СААТ-1 по BLE
│       │   └── device_settings_screen.dart            # Настройки устройства (прошивка, батарея, диагностика)
│       │
│       └── widgets/                                   # ВИДЖЕТЫ (30 файлов)
│           ├── circa_readiness_ring.dart              # Радиальный спидометр восстановления (0–100%)
│           ├── circa_strain_card.dart                 # Карточка нагрузки с зонами HR
│           ├── circa_hypnogram.dart                   # CustomPainter-гипнограмма (Awake/Light/REM/Deep)
│           ├── circa_stress_timeline.dart             # Горизонтальная хроника стресса с тегами
│           ├── circa_day_story_dialog.dart            # Полноэкранный Story-диалог хроники дня
│           ├── circa_share_sheet.dart                 # Шеринг (копирование + растр + формат PNG/Stories)
│           ├── circa_share_card_widget.dart           # Карточка-визитка для шеринга (Gold/Standard)
│           ├── circa_partner_cycle_card.dart          # Карточка партнёра на главном экране
│           ├── circa_partner_cycle_sheet.dart         # Детальный лист биоритма партнёра
│           ├── circa_calibration_card.dart            # Карточка 14-дневной калибровки (авто-скрытие)
│           ├── circa_cycle_card.dart                  # Карточка менструального цикла на дашборде
│           ├── circa_healthspan_card.dart             # Карточка биологического возраста
│           ├── circa_morning_briefing_dialog.dart     # Утренний брифинг от ИИ-тренера
│           ├── circa_morning_peak_banner.dart         # Баннер утреннего пика восстановления
│           ├── circa_recovery_breakdown_sheet.dart    # Детальная разбивка факторов Recovery
│           ├── circa_strain_milestone_badge.dart      # Бейдж достижения нагрузки
│           ├── circa_3d_recovery_orb.dart             # 3D-сфера восстановления с градиентами
│           ├── circa_breathing_retina.dart            # Анимация дыхания (визуализация ВНС)
│           ├── circa_band_radar.dart                  # Радар параметров BLE-браслета
│           ├── circa_sparkline.dart                   # Мини-график (спарклайн) трендов
│           ├── circa_pulsing_logo.dart                # Пульсирующий логотип KALKAN
│           ├── circa_film_grain.dart                  # Плёночное зерно (текстура premium)
│           ├── circa_edge_fade.dart                   # ShaderMask-затухание по краям списков
│           ├── circa_ai_language_pill.dart            # Переключатель языка (овальная капсула)
│           ├── circa_avatar_picker_dialog.dart        # Диалог выбора аватара Барыса
│           ├── circa_friend_detail_sheet.dart         # Детали друга в лиге
│           ├── circa_text_field.dart                  # Стилизованное поле ввода
│           ├── bio_avatar_widget.dart                 # Виджет анимированного Барыса
│           ├── glass_card.dart                        # Стеклянная карточка с backdrop blur
│           └── live_pulse_wave.dart                   # Живая кривая пульса (ECG-стиль)
│
├── test/                                              # ТЕСТЫ (9 файлов, 73+ тестов)
│   ├── widget_test.dart                               # Базовые виджет-тесты
│   ├── models_test.dart                               # Тесты моделей (Telemetry, Profile, Readiness)
│   ├── barys_mascot_test.dart                         # Тесты Барыса-тотема
│   ├── localization_and_entry_test.dart               # Тесты RU/KG локализации
│   ├── stress_timeline_test.dart                      # Тесты стресс-хроники и тегирования
│   ├── menstrual_cycle_and_gender_test.dart           # Тесты цикла, привязки партнёра, gender-табов
│   ├── private_league_test.dart                       # Тесты приватной лиги
│   ├── share_and_passport_test.dart                   # Тесты шеринга и паспорта
│   └── luxury_microdetails_test.dart                  # Тесты premium-деталей (film grain, квесты)
│
└── pubspec.yaml                                       # Flutter 3.x, Dart ^3.11, firebase_core/auth, shared_preferences
```

---

## 2. ДИЗАЙН-СИСТЕМА (3-ЦВЕТНАЯ ПАЛИТРА CIRCA)

### 2.1 Цвета
| Токен | HEX | Назначение |
|-------|-----|------------|
| `stage` | `#12141A` | Глубокий титановый графит (системные бары) |
| `bg` | `#171A23` | Основной фон |
| `surface` | `#1E222D` | Карточки |
| `raised` | `#272C39` | Чипы, подложки |
| `fg` | `#EFF2F7` | Основной текст |
| `muted` | `#9299AA` | Вторичный текст |
| `faint` | `#62697A` | Неактивные элементы |
| `line` | `#FFFFFF` 14% | Тонкие рамки |
| **`sage`** | **`#7D9A92`** | **Восстановление / Успех / Готовность** |
| **`amber`** | **`#C4A574`** | **Нагрузка / Внимание / Фокус** |
| **`rose`** | **`#C45C5C`** | **Пульс / Предупреждение / Стоп** |

### 2.2 Типографика
- **Шрифты:** SF Pro Display → SF Pro Text → -apple-system → Roboto → Inter → Helvetica Neue → Arial
- **Табулярные цифры:** `FontFeature.tabularFigures()` на ВСЕХ числовых виджетах (пульс, ВСР, температура, шаги, таймеры, проценты)
- **Оверлайн-бейджи:** `letterSpacing: 1.5`, `fontWeight: w700`, `fontSize: 10`
- **Метрики:** `fontSize: 48` (героические), `fontSize: 28` (карточки), `letterSpacing: -1.5` (узкий кернинг)

### 2.3 Тактильный отклик (CircaHaptics)
Каждый `onTap` / `onLongPress` сопровождается соответствующим тактильным паттерном:
- `selectionClick()` — чипы, переключатели
- `lightImpact()` — мелкие кнопки
- `mediumImpact()` — карточки, навигация
- `heavyImpact()` — критические действия (шеринг, удаление)

---

## 3. МАТЕМАТИЧЕСКИЕ ДВИЖКИ (ПОЛНЫЕ ФОРМУЛЫ)

### 3.1 Recovery Score (ReadinessEngine) — 0..100%
```
Recovery = 0.35 × HRV_score + 0.25 × RHR_score + 0.20 × Sleep_score + 0.10 × RR_score + 0.10 × Temp_score
```

**HRV_score** = `(текущий_rMSSD / базовый_14д_rMSSD × 85).clamp(10, 100)`
**RHR_score** = если пульс покоя ≤ базы: `95 + (разница × 2.5).clamp(0, 5)`, иначе `90 - (превышение × 7.5)`
**Sleep_score** = взвешенный Sleep Performance (см. 3.3)
**RR_score** = если |ΔRR| ≤ 0.6: `98`, иначе `95 - (|ΔRR| × 25)`
**Temp_score** = если |ΔT| ≤ 0.2°C: `98`, если ΔT > 0.2: `95 - ((ΔT - 0.2) × 60)`, иначе `90 - ((|ΔT| - 0.2) × 30)`

**Зоны:** ≥67 = Optimal (sage), 34..66 = Moderate (amber), <34 = Recovery (rose)

### 3.2 Daily Strain (StrainEngine) — 0.0..21.0
```
TRIMP = Σ(зонаМинуты[i] × вес[i])     где веса = [1, 2, 4, 8, 16]
Strain = 21.0 × (1 - e^(-0.00285 × TRIMP))
```

**Бюджет нагрузки** адаптивный:
- Recovery Optimal: цель 14.0–18.0
- Recovery Moderate: цель 10.0–13.9
- Recovery Low: цель 0.0–9.9

### 3.3 Sleep Performance (SleepEngine) — 0..100%
```
SleepPerformance = 0.40 × Duration + 0.25 × Efficiency + 0.20 × Consistency + 0.15 × Restorative
```

**SleepNeed (динамический):**
```
TotalNeed = BaseNeed(450мин) + SleepDebt(25%_от_долга) + StrainSurcharge(max(0, Strain-10) × 6.5)
```

**Гипнограмма:** 90-минутные ультрадианные циклы (Light → Deep → Light → REM), глубокий сон длиннее в первой половине ночи, REM длиннее под утро, с микропробуждениями WASO.

### 3.4 Stress Timeline (StressEngine)
- 15-минутные скользящие окна с 07:30 до 22:00
- **Уровни:** Rest (0–34, sage), Medium (35–69, amber), High (70–100, rose)
- **Контекстные теги:** Переговоры, Дедлайн, Дорога/Пробка, Кофеин, Тренировка, Конфликт, Соцсети, Медитация, Обед/Пища

### 3.5 Менструальный цикл (MenstrualCycleEngine)
**4 фазы:**
| Фаза | Дни (при 28д) | Температура | Strain-бюджет |
|------|---------------|-------------|---------------|
| Менструальная | 1–5 | Базовый | 6.0–9.5 |
| Фолликулярная | 6–11 | Прохладная (-0.25°C) | 12.0–16.5 |
| Овуляторная | 12–16 | Скачок (+0.20°C) | 13.0–17.5 |
| Лютеиновая | 17–28 | Плато (+0.42°C) | 8.0–11.5 |

**Термический сдвиг:** `expectedDelta(day)` для каждого дня; подтверждение овуляции при `|actual - expected| < 0.45°C`

### 3.6 Biological Age (HealthspanEngine)
```
VO2max = 15.3 × (HRmax / RHR) + (Zone2_hrs × 0.45) + (Zone5_10min × 0.6)
AgeBenefit = vo2Benefit + rhrBenefit + sleepBenefit
BiologicalAge = ChronologicalAge - AgeBenefit
```

---

## 4. BLE-ИНТЕГРАЦИЯ (UteBleBridge)

### 4.1 Архитектура
- **Flutter ↔ Native:** `MethodChannel('barys/ute_ble')` + `EventChannel('barys/ute_ble_stream')`
- **iOS:** `UTEBluetoothRYApi.framework`
- **Android:** Nadal SDK / `com.ute.sdk`

### 4.2 Состояния
`disconnected` → `scanning` → `connecting` → `connected`

### 4.3 Маппинг пакетов
При `connected` входящие нативные пакеты маппируются на `_realTelemetry`:
```dart
heartRate, restingHeartRate, hrv, steps, calories, batteryLevel,
skinTempDeviation, respiratoryRate, isOffWrist, sleepMinutes,
deepSleepMinutes, remSleepMinutes, sleepEfficiency,
currentDayStrain, currentStressScore
```

### 4.4 Защита
- `isOffWrist=true` → замораживает показатели, Recovery=0
- Автореконнект: экспоненциальный откат (1с, 2с, 5с, 15с, 30с)
- Офлайн-буфер: 7 дней в NOR Flash часов

---

## 5. МОДЕЛЬ ДАННЫХ (BleTelemetry)

```dart
class BleTelemetry {
  // Реальное время
  int heartRate;              // Текущий пульс (bpm)
  int steps;                  // Шаги за день
  int calories;               // Активные калории
  int batteryLevel;           // Заряд часов (%)
  bool isConnected;           // Статус BLE
  
  // Ночные биомаркеры (NREM/Deep)
  double hrv;                 // rMSSD (мс)
  int restingHeartRate;       // RHR Nadir (bpm)
  double respiratoryRate;     // Вдохов/мин
  double skinTempDeviation;   // ΔT от личной нормы (°C)
  bool isOffWrist;            // Снят ли браслет
  
  // Сон
  int sleepMinutes;           // Фактический сон
  int deepSleepMinutes;       // Глубокий NREM
  int remSleepMinutes;        // Быстрый REM
  double sleepEfficiency;     // Сон / Постель (0.0..1.0)
  double sleepConsistency;    // Регулярность (0.0..1.0)
  double restorativeSleepRatio; // Пульс < RHR (0.0..1.0)
  List<SleepEpoch> sleepHypnogram;
  
  // Нагрузка
  double currentDayStrain;    // TRIMP (0.0..21.0)
  double yesterdayStrain;     // Вчера
  List<int> zoneMinutes;      // [Z1, Z2, Z3, Z4, Z5]
  
  // Стресс
  int currentStressScore;     // 0..100
}
```

---

## 6. ЭКРАНЫ И ПОВЕДЕНИЕ

### 6.1 DashboardScreen — Главный экран
Hero-карточка Recovery (радиальный спидометр) → Strain → Sleep → Partner (если привязан) → Калибровка (первые 14 дней, авто-скрытие) → Healthspan.

### 6.2 MenstrualCycleScreen — Женский цикл
28-дневная орбита → Быстрая фиксация месячных → Дневник (выделения, спазмы, энергия, настроение, симптомы) → Привязка партнёра по коду KLK-CYC-XXXX.

### 6.3 BioAvatarScreen — Барыс-тотем
Интерактивный тотем → Ежедневные квесты (Сон>7.5ч, Recovery>65%, Питьевой режим, Снижение вечернего стресса) → Народная мудрость.

### 6.4 PrivateLeagueScreen — Лига
5 слотов друзей → Рейтинг по Recovery/Strain → «Отправить импульс силы Барса ✦».

### 6.5 ProfileScreen — Профиль
Биопаспорт → BLE-управление → Язык (RU/KG) → Режим «ГРОЗА» (тест критических протоколов).

---

## 7. ПРАВИЛА ДЛЯ ИИ

1. **НОЛЬ ЭМОДЗИ** в коде. Допускается только `✦` как типографический маркер.
2. **FontFeature.tabularFigures()** на всех динамических числах.
3. **CircaHaptics** или `HapticFeedback` при каждом нажатии.
4. **3 цвета:** sage (зелёный), amber (жёлтый), rose (красный). Никаких радужных градиентов.
5. **Билингвальность:** каждая строка — через `AppStrings.tr(key, language)`.
6. **Тесты:** `flutter analyze` = 0 issues, `flutter test` = 73/73 pass.
7. **Не ломать:** PartnerCycleRepository, UteBleBridge._realTelemetry, SleepEngine.calculate().
8. **Не добавлять:** выбор пола при входе, циферблат вокруг лого, цитаты на сплеше.

---

## 8. ЗАВИСИМОСТИ (pubspec.yaml)

```yaml
environment:
  sdk: ^3.11.1

dependencies:
  flutter: sdk: flutter
  cupertino_icons: ^1.0.8
  shared_preferences: ^2.5.5
  firebase_core: ^4.15.0
  firebase_auth: ^6.7.0

dev_dependencies:
  flutter_test: sdk: flutter
  flutter_lints: ^6.0.0
```

---

*Архив включает полный исходный код (71 файл lib/, 9 файлов test/, ~1 МБ Dart) + этот мастер-документ.*
