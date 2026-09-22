import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../domain/intelligence/day_copy.dart';
import '../widgets/mascot_face.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/intelligence/sleep_engine.dart';
import '../../domain/intelligence/readiness_engine.dart';
import '../../data/storage/climate_mode_store.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/telemetry.dart';
import '../widgets/bio_avatar_widget.dart';
import '../widgets/circa_edge_fade.dart';
import '../widgets/glass_card.dart';

class BioAvatarScreen extends StatefulWidget {
  final UteBleBridge bleBridge;
  final bool embedded;

  const BioAvatarScreen({
    super.key,
    required this.bleBridge,
    this.embedded = false,
  });

  @override
  State<BioAvatarScreen> createState() => _BioAvatarScreenState();
}

class _BioAvatarScreenState extends State<BioAvatarScreen> {
  late BleTelemetry _telemetry;
  late AvatarProfile _profile;
  final PersonalBaseline _baseline = const PersonalBaseline();
  AvatarVisualState? _selectedScenario;
  bool _isMorningWoken = false;
  StreamSubscription<BleTelemetry>? _sub;

  @override
  void initState() {
    super.initState();
    _selectedScenario = null;
    AvatarManager.setDemoOverride(null);
    _telemetry = widget.bleBridge.currentTelemetry;
    _profile = AvatarManager.getProfile(_telemetry, baseline: _baseline);

    _checkMorningWakingStatus();

    AvatarManager.xpNotifier.addListener(_onXpChanged);

    _sub = widget.bleBridge.telemetryStream.listen((data) {
      if (mounted) {
        setState(() {
          _telemetry = data;
          _profile = AvatarManager.getProfile(data, baseline: _baseline);
        });
      }
    });
  }

  void _onXpChanged() {
    if (mounted) {
      setState(() {
        _profile = AvatarManager.getProfile(_telemetry, baseline: _baseline);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    AvatarManager.xpNotifier.removeListener(_onXpChanged);
    super.dispose();
  }

  Future<void> _checkMorningWakingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayKey = 'barys_morning_woken_${now.year}_${now.month}_${now.day}';
      final woken = prefs.getBool(todayKey) ?? false;
      if (mounted) {
        setState(() {
          _isMorningWoken = woken;
        });
      }
    } catch (_) {}
  }

  Future<void> _wakeUpTogether() async {
    HapticFeedback.heavyImpact();
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayKey = 'barys_morning_woken_${now.year}_${now.month}_${now.day}';
      await prefs.setBool(todayKey, true);

      // Начисление утреннего бонуса синхронизации
      await AvatarManager.addXp(50);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isMorningWoken = true;
        _profile = AvatarManager.getProfile(_telemetry, baseline: _baseline);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.sage, width: 1.2),
          ),
          content: Row(
            children: [
              Icon(Icons.wb_sunny_outlined, color: AppColors.sage, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Синхронное пробуждение завершено! +50 XP Барысу.',
                  style: TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _selectScenario(AvatarVisualState? state) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedScenario = state;
      AvatarManager.setDemoOverride(state);
      _profile = AvatarManager.getProfile(_telemetry, baseline: _baseline);
    });
  }

  void _showDevScenariosSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: AppColors.lineStrong, width: 1.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.faint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.tune, color: AppColors.amber, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Сценарии персонажа',
                    style: TextStyle(
                      color: AppColors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Обычный режим берёт данные с часов. Ниже — ручной выбор состояния для проверки.',
                style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
              ),
              SizedBox(height: 16),

              CircaEdgeFade(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildScenarioChip(null, 'По часам'),
                      SizedBox(width: 8),
                      _buildScenarioChip(AvatarVisualState.charged, 'Бодрый (≥75%)'),
                      SizedBox(width: 8),
                      _buildScenarioChip(AvatarVisualState.normal, 'В тонусе (50–74%)'),
                      SizedBox(width: 8),
                      _buildScenarioChip(AvatarVisualState.tired, 'Уставший (<34%)'),
                      SizedBox(width: 8),
                      _buildScenarioChip(AvatarVisualState.sleep, 'Сон / Отбой'),
                      SizedBox(width: 8),
                      _buildScenarioChip(AvatarVisualState.postWorkout, 'После спорта'),
                      SizedBox(width: 8),
                      _buildScenarioChip(AvatarVisualState.meditation, 'Стресс'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEvolutionTiersSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: AppColors.amber, width: 1.2)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.faint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.amber, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Ранги',
                      style: TextStyle(
                        color: AppColors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Ранг растёт от тренировок, сна и закрытых задач.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
                ),
                SizedBox(height: 16),

                for (final tier in BarysEvolutionTier.values)
                  _buildEvolutionTierCard(tier, isCurrent: tier == _profile.evolutionTier),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEvolutionTierCard(BarysEvolutionTier tier, {required bool isCurrent}) {
    final isUnlocked = _profile.level >= tier.minLevel;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent
            ? tier.auraColor.withValues(alpha: 0.12)
            : AppColors.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? tier.auraColor
              : isUnlocked
                  ? AppColors.lineStrong
                  : AppColors.line,
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tier.auraColor,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    tier.title.toUpperCase(),
                    style: TextStyle(
                      color: isUnlocked ? AppColors.fg : AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? tier.auraColor.withValues(alpha: 0.2)
                      : AppColors.stage,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCurrent
                      ? 'ТЕКУЩИЙ'
                      : isUnlocked
                          ? 'ОТКРЫТ'
                          : 'С УРОВНЯ ${tier.minLevel}',
                  style: TextStyle(
                    color: isCurrent ? tier.auraColor : AppColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            tier.description,
            style: TextStyle(color: AppColors.fg, fontSize: 11, height: 1.3),
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.amber, size: 12),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  tier.unlockBenefit,
                  style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isMorningTime = now.hour >= 5 && now.hour < 12;
    final progress = AvatarManager.getEvolutionProgress(_profile.level, _profile.currentXp);
    final palette = KalkanColors.of(context);
    final canPop = Navigator.of(context).canPop() && !widget.embedded;

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        return Scaffold(
          backgroundColor: palette.bg,
          appBar: AppBar(
            backgroundColor: palette.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: canPop
                ? IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: palette.secondary, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            automaticallyImplyLeading: false,
            title: Text(
              AppStrings.tr('mascot_title', language),
              style: TextStyle(
                color: palette.fg,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                fontFamily: 'Manrope',
              ),
            ),
            centerTitle: false,
            actions: const [],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                children: [
                  Center(
                    child: MascotFace(
                      state: AvatarManager.calculateState(_telemetry, baseline: _baseline),
                      size: 196,
                      climate: ClimateMode.normal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    DayCopy.morning(
                      sleepScore: SleepEngine.calculate(telemetry: _telemetry, baseline: _baseline).sleepPerformanceScore,
                      tMin: StrainEngine.evaluate(
                        currentStrain: _telemetry.currentDayStrain > 0 ? _telemetry.currentDayStrain : 0,
                        recoveryZone: ReadinessEngine.calculate(_telemetry, baseline: _baseline).zone,
                      ).targetStrainMin,
                      tMax: StrainEngine.evaluate(
                        currentStrain: _telemetry.currentDayStrain > 0 ? _telemetry.currentDayStrain : 0,
                        recoveryZone: ReadinessEngine.calculate(_telemetry, baseline: _baseline).zone,
                      ).targetStrainMax,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.fg, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  if (isMorningTime && !_isMorningWoken)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.amber.withValues(alpha: 0.45)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocaleNotifier.pick('Доброе утро', 'Кутман таң', 'Good morning'),
                            style: TextStyle(color: palette.fg, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppLocaleNotifier.pick(
                              'Отметьте пробуждение — персонаж синхронизируется с сегодняшним днём.',
                              'Ойгонууну белгилеңиз — каарман бүгүнкү күнгө шайкештелет.',
                              'Mark wake-up — character syncs with today.',
                            ),
                            style: TextStyle(color: palette.secondary, fontSize: 13, height: 1.35),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _wakeUpTogether,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.amber,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(AppLocaleNotifier.pick('Отметить утро  +50 XP', 'Таңды белгилөө  +50 XP', 'Log morning  +50 XP')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _profile.evolutionTier.localizedTitle(language),
                                style: TextStyle(
                                  color: palette.fg,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Text(
                              '${_profile.currentXp} / ${_profile.maxXp} XP',
                              style: TextStyle(color: palette.secondary, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocaleNotifier.pick(
                            'Уровень ${_profile.level}',
                            '${_profile.level}-деңгээл',
                            'Level ${_profile.level}',
                          ),
                          style: TextStyle(color: palette.secondary, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _profile.progressRatio,
                            backgroundColor: palette.raised,
                            valueColor: AlwaysStoppedAnimation<Color>(_profile.evolutionTier.auraColor),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              progress.nextTier != null
                                  ? AppLocaleNotifier.pick(
                                      'До ${progress.nextTier!.localizedShortName(language)}: ${progress.xpToNextTier} XP',
                                      '${progress.nextTier!.localizedShortName(language)} чейин: ${progress.xpToNextTier} XP',
                                      'To ${progress.nextTier!.localizedShortName(language)}: ${progress.xpToNextTier} XP',
                                    )
                                  : AppLocaleNotifier.pick('Максимальный ранг', 'Жогорку даража', 'Maximum rank'),
                              style: TextStyle(color: palette.secondary, fontSize: 11),
                            ),
                            InkWell(
                              onTap: _showEvolutionTiersSheet,
                              child: Text(
                                AppLocaleNotifier.pick('Все ранги', 'Бардык даражалар', 'All ranks'),
                                style: TextStyle(color: AppColors.sage, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildDailyQuestsChecklist(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScenarioChip(AvatarVisualState? state, String label) {
    final isSelected = _selectedScenario == state;
    final color = state?.badgeColor ?? AppColors.amber;
    return GestureDetector(
      onTap: () => _selectScenario(state),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.line,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.fg : AppColors.muted,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyQuestsChecklist() {
    final completedCount = _profile.quests.where((q) => q.isCompleted).length;
    final totalCount = _profile.quests.length;
    final allDone = totalCount > 0 && completedCount == totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Шапка чек-листа со швейцарским прогресс-баром
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _profile.isPauseMode ? 'РЕЖИМ ВОССТАНОВЛЕНИЯ (ЦНС)' : 'ЕЖЕДНЕВНЫЕ ЗАДАЧИ АКТИВНОСТИ',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            Row(
              children: [
                Text(
                  '$completedCount ИЗ $totalCount ВЫПОЛНЕНО',
                  style: TextStyle(
                    color: allDone ? AppColors.sage : AppColors.muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(width: 8),
                // 3 сегментных микро-индикатора
                Row(
                  children: List.generate(totalCount, (index) {
                    final isFilled = index < completedCount;
                    return Container(
                      margin: const EdgeInsets.only(left: 3),
                      width: 14,
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: isFilled ? AppColors.sage : AppColors.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 8),

        // Полноэкранный чек-лист микро-квестов
        ..._profile.quests.map((quest) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _handleQuestTap(quest),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Индикатор выполнения сенсором
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: quest.isCompleted
                            ? AppColors.sage.withValues(alpha: 0.18)
                            : AppColors.raised,
                        border: Border.all(
                          color: quest.isCompleted ? AppColors.sage : AppColors.line,
                          width: quest.isCompleted ? 1.5 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          quest.isCompleted ? Icons.check : (quest.icon ?? Icons.radio_button_unchecked),
                          color: quest.isCompleted ? AppColors.sage : AppColors.muted,
                          size: quest.isCompleted ? 15 : 13,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),

                    // Текст квеста и статус
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quest.title,
                            style: TextStyle(
                              color: quest.isCompleted ? AppColors.fg : AppColors.fg.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            quest.subtitle.isNotEmpty
                                ? quest.subtitle
                                : '${quest.current} / ${quest.target} ${quest.unit}',
                            style: TextStyle(
                              color: quest.isCompleted ? AppColors.sage.withValues(alpha: 0.85) : AppColors.faint,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),

                    // Индикатор XP / статуса выполнения сенсором
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: quest.isCompleted
                            ? AppColors.sage.withValues(alpha: 0.12)
                            : AppColors.raised,
                        borderRadius: BorderRadius.circular(8),
                        border: quest.isCompleted
                            ? Border.all(color: AppColors.sage.withValues(alpha: 0.4))
                            : null,
                      ),
                      child: Text(
                        quest.isCompleted ? 'ВЫПОЛНЕНО' : '+${quest.rewardXp} XP',
                        style: TextStyle(
                          color: quest.isCompleted ? AppColors.sage : AppColors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // Торжественная карточка завершения всего чек-листа
        if (allDone)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.5), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: AppColors.amber.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: const [
                Icon(Icons.stars, color: AppColors.amber, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '✦ ВСЕ МИКРО-КВЕСТЫ ЗАКРЫТЫ · ДНЕВНОЙ РИТУАЛ ВЫПОЛНЕН ✦',
                    style: TextStyle(
                      color: AppColors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _handleQuestTap(DailyQuest quest) {
    CircaHaptics.ringZoneTick();
    String message;
    if (quest.isCompleted) {
      message = 'Задание выполнено! Сенсоры KALKAN СААТ-1 зафиксировали целевой показатель.';
    } else if (quest.id == 'quest_strain') {
      message = 'Дневная нагрузка накапливается автоматически при ношении СААТ-1 во время активности.';
    } else if (quest.id == 'quest_steps') {
      message = 'Шаги учитываются акселерометром СААТ-1 автоматически в режиме реального времени.';
    } else if (quest.id == 'quest_sleep') {
      message = 'Сон и фазы восстановления анализируются датчиками СААТ-1 во время ночного отдыха.';
    } else {
      message = 'Показатели регистрируются датчиками KALKAN СААТ-1 автоматически.';
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppColors.line),
        ),
        content: Row(
          children: [
            Icon(
              quest.isCompleted ? Icons.check_circle_outline : Icons.sensors,
              color: quest.isCompleted ? AppColors.sage : AppColors.amber,
              size: 18,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
