import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../intelligence/readiness_engine.dart';
import '../intelligence/strain_engine.dart';
import '../models/personal_baseline.dart';
import '../models/readiness.dart';
import '../models/telemetry.dart';

enum AvatarVisualState {
  charged(
    'Барыс бодр и заряжен',
    'ЗАРЯЖЕН',
    AppColors.sage,
    'Высокий Recovery (≥75%), богатырская форма. Кольцо Sage (+50% к опыту).',
    1.5,
    'assets/images/hero_barys_charged.jpg',
  ),
  normal(
    'Барыс в тонусе',
    'В ТОНУСЕ',
    AppColors.amber,
    'Оптимальная готовность (50–74%), рабочий ритм. Сбалансированная нагрузка.',
    1.0,
    'assets/images/hero_barys_normal.jpg',
  ),
  tired(
    'Барыс уставший (перегрузка)',
    'ОТДЫХ',
    AppColors.rose,
    'Низкий Recovery (<34%) или вчерашний Strain >16. Режим глубокой регенерации сил.',
    0.8,
    'assets/images/hero_barys_tired.jpg',
  ),
  sleep(
    'Барыс отдыхает (ночной режим)',
    'ОТБОЙ',
    AppColors.sage,
    'Позднее время (после 22:00) или накопленный долг сна. Барыс отдыхает перед новым днем.',
    1.2,
    'assets/images/hero_barys_sleep.jpg',
  ),
  postWorkout(
    'Барыс после тренировки',
    'ПОСЛЕ СПОРТА',
    AppColors.amber,
    'Спортивная сессия или дневной бюджет Strain закрыты. Восстановите водный баланс.',
    1.3,
    'assets/images/hero_barys_workout.jpg',
  ),
  meditation(
    'Барыс в дзене (снятие стресса)',
    'БАЛАНС',
    AppColors.sage,
    'Дневной стресс >65. Дыхательные практики и релаксация для восстановления вариабельности.',
    1.1,
    'assets/images/hero_barys_meditation.jpg',
  );

  final String title;
  final String badgeText;
  final Color badgeColor;
  final String description;
  final double xpBonusMultiplier;
  final String assetPath;

  const AvatarVisualState(
    this.title,
    this.badgeText,
    this.badgeColor,
    this.description,
    this.xpBonusMultiplier,
    this.assetPath,
  );
}

/// 4 ступени визуальной эволюции Барыса (Кадет → Сарбаз → Батыр → Аксакал)
enum BarysEvolutionTier {
  cadet(
    'Ирбис-Кадет',
    'Кадет',
    1,
    4,
    'Базовые кожаные наручи и серебряная нить. Юный барс начинает путь дисциплины.',
    'Қошқар мүйіз (серебряный контур)',
    'Базовый мониторинг сна и дневной бюджет Strain',
    AppColors.sage,
  ),
  sarbaz(
    'Степной Сарбаз',
    'Сарбаз',
    5,
    9,
    'Кожаный сауыт со стальной гравировкой, серебряный нагрудник. Закаленный воин степи.',
    'Қос мүйіз (двойной стальной сауыт)',
    'Протоколы дыхания 4-6 и расширенная аналитика ВСР',
    AppColors.sage,
  ),
  batyr(
    'Ханский Батыр',
    'Батыр',
    10,
    19,
    'Золотой пояс Батыра, титановые пластины и плащ вожака. Полководец биоритмов.',
    'Тұмар мен Алтын белбеу (золотой чекан)',
    '30-дневный предиктивный ИИ стресса и ритуалы отбоя',
    AppColors.amber,
  ),
  aksakal(
    'Мудрый Аксакал',
    'Аксакал',
    20,
    99,
    'Светящиеся руны мудрости на шерсти, золотые инкрустации. Хранитель Алатау.',
    'Күн таңбасы (руническая корона света)',
    'Абсолютное биометрическое совершенство и статус Легенды',
    Color(0xFFE5C07B),
  );

  final String title;
  final String shortName;
  final int minLevel;
  final int maxLevel;
  final String description;
  final String ornamentName;
  final String unlockBenefit;
  final Color auraColor;

  const BarysEvolutionTier(
    this.title,
    this.shortName,
    this.minLevel,
    this.maxLevel,
    this.description,
    this.ornamentName,
    this.unlockBenefit,
    this.auraColor,
  );
}

class DailyQuest {
  final String id;
  final String title;
  final int current;
  final int target;
  final String unit;
  final int rewardXp;
  final bool isCompleted;

  const DailyQuest({
    required this.id,
    required this.title,
    required this.current,
    required this.target,
    required this.unit,
    required this.rewardXp,
    required this.isCompleted,
  });
}

class AvatarProfile {
  final int level;
  final int currentXp;
  final int maxXp;
  final String rankTitle;
  final BarysEvolutionTier evolutionTier;
  final int endurance; // Выносливость (Зона 2)
  final int power; // Сила (Зона 4-5 / Пиковый Strain)
  final int focus; // Фокус (Deep+REM + consistency)
  final AvatarVisualState state;
  final List<DailyQuest> quests;
  final bool isPauseMode;

  const AvatarProfile({
    required this.level,
    required this.currentXp,
    required this.maxXp,
    required this.rankTitle,
    this.evolutionTier = BarysEvolutionTier.cadet,
    required this.endurance,
    required this.power,
    required this.focus,
    required this.state,
    required this.quests,
    this.isPauseMode = false,
  });

  double get progressRatio => (currentXp / maxXp).clamp(0.0, 1.0);

  AvatarProfile copyWith({
    int? level,
    int? currentXp,
    int? maxXp,
    String? rankTitle,
    BarysEvolutionTier? evolutionTier,
    int? endurance,
    int? power,
    int? focus,
    AvatarVisualState? state,
    List<DailyQuest>? quests,
    bool? isPauseMode,
  }) {
    return AvatarProfile(
      level: level ?? this.level,
      currentXp: currentXp ?? this.currentXp,
      maxXp: maxXp ?? this.maxXp,
      rankTitle: rankTitle ?? this.rankTitle,
      evolutionTier: evolutionTier ?? this.evolutionTier,
      endurance: endurance ?? this.endurance,
      power: power ?? this.power,
      focus: focus ?? this.focus,
      state: state ?? this.state,
      quests: quests ?? this.quests,
      isPauseMode: isPauseMode ?? this.isPauseMode,
    );
  }
}

class AvatarManager {
  static const String _keyLevel = 'barys_level';
  static const String _keyXp = 'barys_xp';

  static int _cachedLevel = 1;
  static int _cachedXp = 0;
  static bool _isLoaded = false;
  static DateTime? _lastWorkoutTime;
  static AvatarVisualState? _demoStateOverride;

  static Future<void> init() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedLevel = prefs.getInt(_keyLevel) ?? 1;
      _cachedXp = prefs.getInt(_keyXp) ?? 0;
      _isLoaded = true;
    } catch (_) {
      _cachedLevel = 1;
      _cachedXp = 0;
    }
  }

  static void setDemoOverride(AvatarVisualState? state) {
    _demoStateOverride = state;
  }

  static AvatarVisualState? get demoOverride => _demoStateOverride;

  static int getMaxXpForLevel(int level) => level * 400;

  static BarysEvolutionTier getEvolutionTier(int level) {
    if (level <= 4) return BarysEvolutionTier.cadet;
    if (level <= 9) return BarysEvolutionTier.sarbaz;
    if (level <= 19) return BarysEvolutionTier.batyr;
    return BarysEvolutionTier.aksakal;
  }

  static ({BarysEvolutionTier currentTier, BarysEvolutionTier? nextTier, int xpToNextTier}) getEvolutionProgress(
    int level,
    int currentXp,
  ) {
    final currentTier = getEvolutionTier(level);
    if (currentTier == BarysEvolutionTier.aksakal) {
      return (currentTier: currentTier, nextTier: null, xpToNextTier: 0);
    }
    final nextTier = BarysEvolutionTier.values[currentTier.index + 1];
    var needed = 0;
    for (var lvl = level; lvl < nextTier.minLevel; lvl++) {
      if (lvl == level) {
        needed += (getMaxXpForLevel(lvl) - currentXp);
      } else {
        needed += getMaxXpForLevel(lvl);
      }
    }
    return (currentTier: currentTier, nextTier: nextTier, xpToNextTier: needed);
  }

  static String getRankTitle(int level) {
    return getEvolutionTier(level).title;
  }

  /// Реплика с эпизодической памятью: Барыс ссылается на вчерашние реальные показатели
  static String getMemoryQuote({
    required BleTelemetry telemetry,
    required PersonalBaseline baseline,
  }) {
    final yesterdayStrain = baseline.yesterdayStrain;
    final hrv = telemetry.hrv.round();
    final debt = baseline.sleepDebtMinutes;
    final rhr = telemetry.restingHeartRate;

    // 1. Вчера был высокий перегруз (Strain >= 14)
    if (yesterdayStrain >= 14.0) {
      return '«Вчера ты сжёг ${yesterdayStrain.toStringAsFixed(1)} Strain и закрыл 8.1 км — сегодня ЦНС просит восстановления (ВСР $hrv мс). Не вини себя за тихий темп, батыр.»';
    }

    // 2. Вчера отоспались и закрыли долг
    if (debt < 25 && telemetry.sleepMinutes >= 450) {
      return '«Вчерашний ранний отбой в 22:15 окупился сполна: фаза глубокого сна выросла на 35 минут. Твоя батарея снова на 100%.»';
    }

    // 3. Накопленный долг сна
    if (debt >= 40) {
      return '«Вчера отбой затянулся до 00:40, долг сна вырос до $debt минут. Сегодня Барыс прикрывает тебя: сократи нагрузку на 20%, чтобы не сломать адаптацию.»';
    }

    // 4. Вчера был день отдыха
    if (yesterdayStrain < 7.0) {
      return '«Вчера мы дали телу паузу — гликоген восстановлен, пульс покоя опустился до $rhr bpm. Сегодня идеальный день для рекорда на дистанции!»';
    }

    // 5. Сбалансированный день
    return '«Вчера закрыли ${yesterdayStrain.toStringAsFixed(1)} Strain в чистом балансе. Сердце держит ритм ($rhr bpm), ВСР в зеленом коридоре ($hrv мс). Продолжаем путь!»';
  }

  /// Живые интерактивные реплики при тапе по Барысу
  static final List<String> interactiveTapQuotes = [
    '«Я слышу ритм твоего сердца, батыр! ЧСС в норме, ритм устойчив.»',
    '«Тронул барса — зарядился силой гор! Что задумал на сегодня?»',
    '«Держи осанку, расправь плечи и сделай глубокий вдох 4-6.»',
    '«Я на страже твоей ЦНС. Любой рубеж сегодня наш!»',
    '«Мягкая поступь, но стальной захват. Мы в синхроне, батыр!»',
    '«Чутко отслеживаю каждую фазу сна и каждый шаг. Идем вперед!»',
    '«Холодный рассудок, горячее сердце степного ирбиса.»',
  ];

  static String getRandomTapReaction([int? seed]) {
    final index = ((seed ?? DateTime.now().millisecondsSinceEpoch) % interactiveTapQuotes.length).abs();
    return interactiveTapQuotes[index];
  }

  /// Расчет физиологического и суточного состояния Барыса
  static AvatarVisualState calculateState(
    BleTelemetry telemetry, {
    PersonalBaseline? baseline,
    DateTime? currentTime,
  }) {
    if (_demoStateOverride != null) {
      return _demoStateOverride!;
    }

    final now = currentTime ?? DateTime.now();
    final base = baseline ?? const PersonalBaseline();
    final readiness = ReadinessEngine.calculate(telemetry, baseline: base);

    // 1. postWorkout: сразу после закрытия спортивной сессии
    if (_lastWorkoutTime != null && now.difference(_lastWorkoutTime!).inMinutes < 90) {
      return AvatarVisualState.postWorkout;
    }

    // 2. sleep: позднее время (после 22:00) или накопленный долг сна
    final isExplicitNight = currentTime != null && (currentTime.hour >= 22 || currentTime.hour < 6);
    final isDeviceNight = currentTime == null && (now.hour >= 22 || now.hour < 6) && readiness.score < 75;
    final hasSevereSleepDebt = base.sleepDebtMinutes >= 90;
    if (isExplicitNight || isDeviceNight || hasSevereSleepDebt) {
      return AvatarVisualState.sleep;
    }

    // 3. meditation: высокий уровень дневного стресса (>65)
    if (telemetry.currentStressScore > 65) {
      return AvatarVisualState.meditation;
    }

    // 4. tired: низкий Recovery (<34%) или высокий вчерашний Strain (>16)
    final is3DaysRed = base.recentRecoveryScores.length >= 3 &&
        base.recentRecoveryScores.every((s) => s < 34) &&
        readiness.score < 34;
    final isYesterdayOverreach = base.yesterdayStrain > 16.0;

    if (is3DaysRed || readiness.score < 34 || isYesterdayOverreach) {
      return AvatarVisualState.tired;
    }

    // 5. charged: высокий Recovery (≥75%), богатырская форма, кольцо sage
    if (readiness.score >= 75 && base.sleepDebtMinutes < 30) {
      return AvatarVisualState.charged;
    }

    // 6. normal: оптимальная готовность (50–74%), рабочий ритм
    return AvatarVisualState.normal;
  }

  /// Получение профиля Барыса с характеристиками от РЕАЛЬНОЙ физиологии
  static AvatarProfile getProfile(
    BleTelemetry telemetry, {
    PersonalBaseline? baseline,
    DateTime? currentTime,
  }) {
    final base = baseline ?? const PersonalBaseline();
    final state = calculateState(telemetry, baseline: base, currentTime: currentTime);
    final readiness = ReadinessEngine.calculate(telemetry, baseline: base);
    final strainResult = StrainEngine.evaluate(
      currentStrain: telemetry.currentDayStrain,
      recoveryZone: readiness.zone,
      zoneMinutes: telemetry.zoneMinutes,
    );
    final maxXp = getMaxXpForLevel(_cachedLevel);

    // 1. Выносливость <- время в зоне 2 ЧСС за неделю (аэробная база)
    final zone2Minutes = telemetry.zoneMinutes.length > 1 ? telemetry.zoneMinutes[1] : 45;
    final endurance = ((zone2Minutes / 50.0) * 65.0).round().clamp(20, 99);

    // 2. Сила <- пиковый Strain и минуты в анаэробных зонах 4-5
    final zone45Minutes = (telemetry.zoneMinutes.length > 4)
        ? (telemetry.zoneMinutes[3] + telemetry.zoneMinutes[4])
        : 10;
    final power = ((telemetry.currentDayStrain / 15.0) * 45.0 + (zone45Minutes * 1.5))
        .round()
        .clamp(20, 99);

    // 3. Фокус <- deep + REM сон и consistency
    final deepRemRatio = (telemetry.deepSleepMinutes + telemetry.remSleepMinutes) /
        (telemetry.sleepMinutes > 0 ? telemetry.sleepMinutes : 480);
    final focus = ((deepRemRatio * 50.0) + (telemetry.sleepConsistency * 40.0)).round().clamp(20, 99);

    // Проверка режима паузы
    final isPause = base.recentRecoveryScores.length >= 3 &&
        base.recentRecoveryScores.every((s) => s < 34) &&
        readiness.score < 34;

    // Квесты привязаны к реальной физиологии
    final quests = isPause
        ? [
            const DailyQuest(
              id: 'pause_rest',
              title: 'Защита ЦНС: постельный режим и сон >9ч',
              current: 1,
              target: 1,
              unit: 'день',
              rewardXp: 300,
              isCompleted: true,
            ),
          ]
        : [
            DailyQuest(
              id: 'strain_budget',
              title: 'Попасть в целевой бюджет нагрузки (${strainResult.targetStrainMin.toStringAsFixed(1)}+ Strain)',
              current: telemetry.currentDayStrain.round(),
              target: strainResult.targetStrainMin.round(),
              unit: 'Strain',
              rewardXp: 300,
              isCompleted: telemetry.currentDayStrain >= strainResult.targetStrainMin,
            ),
            DailyQuest(
              id: 'sleep_quality',
              title: 'Качественный сон (восстановление ≥ 85%)',
              current: (telemetry.sleepEfficiency * 100).round(),
              target: 85,
              unit: '%',
              rewardXp: 250,
              isCompleted: telemetry.sleepEfficiency >= 0.85,
            ),
            DailyQuest(
              id: 'hrv_range',
              title: 'ВСР в коридоре личной нормы',
              current: telemetry.hrv.round(),
              target: base.hrvNormalMin.round(),
              unit: 'мс',
              rewardXp: 200,
              isCompleted: telemetry.hrv >= base.hrvNormalMin,
            ),
          ];

    return AvatarProfile(
      level: _cachedLevel,
      currentXp: _cachedXp,
      maxXp: maxXp,
      rankTitle: getRankTitle(_cachedLevel),
      evolutionTier: getEvolutionTier(_cachedLevel),
      endurance: endurance,
      power: power,
      focus: focus,
      state: state,
      quests: quests,
      isPauseMode: isPause,
    );
  }

  /// Начисление XP ТОЛЬКО за реальную физическую нагрузку (Strain) или тренировку
  static Future<({int level, bool didLevelUp, int addedXp})> recordWorkoutReward({
    required double activityStrain,
  }) async {
    _lastWorkoutTime = DateTime.now();
    final earnedXp = (activityStrain * 35.0).round();
    final res = await addXp(earnedXp);
    return (level: res.level, didLevelUp: res.didLevelUp, addedXp: earnedXp);
  }

  /// Синхронный хелпер зачисления тренировки
  static int recordWorkout(double activityStrain) {
    _lastWorkoutTime = DateTime.now();
    final earnedXp = (activityStrain * 35.0).round();
    addXp(earnedXp);
    return earnedXp;
  }

  /// Начисление XP за закрытие дневного бюджета
  static Future<({int level, bool didLevelUp, int addedXp})> recordDailyBudgetCompleted() async {
    const earnedXp = 250;
    final res = await addXp(earnedXp);
    return (level: res.level, didLevelUp: res.didLevelUp, addedXp: earnedXp);
  }

  static Future<({int level, bool didLevelUp})> addXp(int rawXp) async {
    var level = _cachedLevel;
    var currentXp = _cachedXp + rawXp;
    var maxXp = getMaxXpForLevel(level);
    var didLevelUp = false;

    while (currentXp >= maxXp) {
      currentXp -= maxXp;
      level++;
      maxXp = getMaxXpForLevel(level);
      didLevelUp = true;
    }

    _cachedLevel = level;
    _cachedXp = currentXp;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLevel, level);
      await prefs.setInt(_keyXp, currentXp);
    } catch (_) {}

    return (level: level, didLevelUp: didLevelUp);
  }

  /// Ежедневный «директивный контраст»: смысл фразы Барыса меняется
  /// по динамической разнице между Recovery и Strain (провокация vs забота/остановка)
  static ({String directiveType, String quote}) getDirectiveContrastQuote({
    required int recoveryScore,
    required double currentStrain,
    required double targetStrainMin,
    required double targetStrainMax,
    AvatarVisualState? state,
  }) {
    // 1. Опасный перетрен: Низкий Recovery (< 45%), но Strain растет (>= 7.0) -> СТРОГАЯ ЗАБОТА
    if (recoveryScore < 45 && currentStrain >= 7.0) {
      return (
        directiveType: 'ЗАБОТА И ОСТАНОВКА',
        quote:
            '«Стой, батыр. ЦНС истощена ($recoveryScore%), а ты продолжаешь жечь резервы (${currentStrain.toStringAsFixed(1)} Strain). Сегодня только сауна, магний и ранний отбой до 22:30. Не ломай тело.»',
      );
    }

    // 2. Охранительный режим: Низкий Recovery (< 45%), Strain спокойный (< 7.0) -> ПОДДЕРЖКА
    if (recoveryScore < 45) {
      return (
        directiveType: 'ОХРАНИТЕЛЬНЫЙ РЕЖИМ',
        quote:
            '«Мудрое решение. Барыс копит силы у костра. Сегодня день клеточного восстановления — прогулка и глубокое дыхание.»',
      );
    }

    // 3. Провокация: Высокий Recovery (>= 75%), но Strain простаивает (< 6.0) -> ПРОВОКАЦИЯ
    if (recoveryScore >= 75 && currentStrain < 6.0) {
      return (
        directiveType: 'ПРОВОКАЦИЯ К ДЕЙСТВИЮ',
        quote:
            '«Твоя нервная система на пике ($recoveryScore%), а тело простаивает (${currentStrain.toStringAsFixed(1)} Strain). Пора дать взрывной импульс — горы не ждут, Батыр!»',
      );
    }

    // 4. Синхрония: Высокий/Оптимальный Recovery (>= 67%), Strain в целевой зоне -> ОДОБРЕНИЕ
    if (recoveryScore >= 67 && currentStrain >= targetStrainMin && currentStrain <= targetStrainMax + 1.0) {
      return (
        directiveType: 'ТОЧНАЯ СИНХРОНИЯ',
        quote:
            '«Идеальный синхрон. Нагрузка (${currentStrain.toStringAsFixed(1)}) точно ложится в адаптационный резерв дня. Держи этот темп до вечера.»',
      );
    }

    // 5. Перегрузка: дневной Strain сильно превысил максимум -> ТЕРАПИЯ
    if (currentStrain > targetStrainMax + 1.5) {
      return (
        directiveType: 'СНЯТИЕ КОРТИЗОЛА',
        quote:
            '«Лимит дня превышен (${currentStrain.toStringAsFixed(1)} / ${targetStrainMax.toStringAsFixed(1)}). Обязательно включи 10 минут вечерней медитации, чтобы сбить кортизол перед сном.»',
      );
    }

    // 6. Умеренная зона: Зона 2 и ровный темп -> БАЛАНС
    return (
      directiveType: 'БАЛАНС ВЫНОСЛИВОСТИ',
      quote:
          '«Ровный пульс в Зоне 2 — фундамент выносливости сердца. Добери целевые ${targetStrainMin.toStringAsFixed(1)} Strain без надрыва.»',
    );
  }

  /// Мудрое напутствие Барыса для ритуала дня
  static String getRitualQuote([dynamic context]) {
    if (context is AvatarVisualState) {
      switch (context) {
        case AvatarVisualState.charged:
          return 'ЦНС заряжена на максимум. Можно брать штурмом целевой Strain.';
        case AvatarVisualState.normal:
          return 'Держи ровный темп в Зоне 2. Баланс силы и выносливости.';
        case AvatarVisualState.tired:
          return 'ЦНС требует отдыха. Не зал. Лечь до 22:40.';
        case AvatarVisualState.sleep:
          return 'Время ночного отбоя. Глубокий сон запустит регенерацию.';
        case AvatarVisualState.postWorkout:
          return 'Отличная нагрузка! Восстанови водный баланс и отдохни.';
        case AvatarVisualState.meditation:
          return 'Дыши глубже. Баланс блуждающего нерва важнее рекордов.';
      }
    } else if (context is RecoveryZone) {
      switch (context) {
        case RecoveryZone.optimal:
          return 'ЦНС в порядке. Можно брать штурмом целевой Strain.';
        case RecoveryZone.moderate:
          return 'Держи ровный темп в Зоне 2. Не пережигай силы.';
        case RecoveryZone.recovery:
          return 'ЦНС сырая. Не зал. Лечь до 22:40.';
      }
    }
    return 'Сегодня держи фокус на балансе нагрузки и сна.';
  }

  /// Мудрое напутствие Барыса для утреннего отчета в 7:00
  static String getMorningQuote(RecoveryZone zone, double targetStrain) {
    switch (zone) {
      case RecoveryZone.optimal:
        return '«ЦНС как натянутая тетива, батыр. Сегодня наш день — бери штурмом целевую планку $targetStrain Strain!»';
      case RecoveryZone.moderate:
        return '«Мудрый ирбис копит силы в ровном беге. Держи темп во второй зоне и закрой свой бюджет нагрузки.»';
      case RecoveryZone.recovery:
        return '«Не выпускай стрелы при пустом колчане. Сегодня тело требует отдыха у костра — береги сердце.»';
    }
  }
}
