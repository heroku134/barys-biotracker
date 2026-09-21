import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
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

  const BioAvatarScreen({
    super.key,
    required this.bleBridge,
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

  @override
  void initState() {
    super.initState();
    _selectedScenario = AvatarManager.demoOverride;
    _telemetry = widget.bleBridge.currentTelemetry;
    _profile = AvatarManager.getProfile(_telemetry, baseline: _baseline);

    _checkMorningWakingStatus();

    AvatarManager.xpNotifier.addListener(_onXpChanged);

    widget.bleBridge.telemetryStream.listen((data) {
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
                    'РЕЖИМ ОТЛАДКИ МАСКОТА (DEV)',
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
              const Text(
                'В основном интерфейсе Барыс живёт автономно на основе данных пульса и ВСР. Для демонстрации переключите сценарий вручную:',
                style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
              ),
              SizedBox(height: 16),

              CircaEdgeFade(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildScenarioChip(null, 'Автономный (ИИ)'),
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
                      _buildScenarioChip(AvatarVisualState.meditation, 'Баланс / Дзен'),
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
                      'ПУТЬ ЭВОЛЮЦИИ БАРЫСА',
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
                const Text(
                  'Каждая тренировка, каждый закрытый Strain и каждая ночь сна обогащают костюм и статус степного ирбиса:',
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
              const Icon(Icons.auto_awesome, color: AppColors.amber, size: 12),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  tier.unlockBenefit,
                  style: const TextStyle(
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

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        return Scaffold(
          backgroundColor: AppColors.stage,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: AppColors.muted, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              AppStrings.tr('mascot_title', language),
              style: TextStyle(
                color: AppColors.fg,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.4,
              ),
            ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: AppColors.muted, size: 20),
            tooltip: 'Режим отладки маскота',
            onPressed: _showDevScenariosSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    SizedBox(height: 14),

                    // 1. Интерактивный Аватар Барыса (Тап = вздох, покач головой, реплика)
                    Center(
                      child: BioAvatarWidget(
                        state: _profile.state,
                        bpm: _telemetry.heartRate,
                        size: 230,
                        evolutionTier: _profile.evolutionTier,
                      ),
                    ),

                    SizedBox(height: 6),

                    // 2. Утреннее совместное пробуждение (если утро)
                    if (isMorningTime && !_isMorningWoken)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.amber.withValues(alpha: 0.18),
                              AppColors.surface,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.amber.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.wb_sunny_outlined, color: AppColors.amber, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'УТРЕННЕЕ ПРОБУЖДЕНИЕ: БАРЫС ПРОСЫПАЕТСЯ',
                                  style: TextStyle(
                                    color: AppColors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            const Text(
                              '«Доброе утро, батыр. Я спал с тобой 7ч 42м. Твой ночной пульс опускался до 52 bpm — мы восстановились. Готов встретить новый день?»',
                              style: TextStyle(
                                color: AppColors.fg,
                                fontSize: 12,
                                height: 1.35,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _wakeUpTogether,
                                icon: Icon(Icons.check, size: 16, color: AppColors.stage),
                                label: const Text(
                                  'ПРОСНУТЬСЯ ВМЕСТЕ (+50 XP)',
                                  style: TextStyle(
                                    color: AppColors.stage,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.amber,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 4. Карточка прогрессии эволюции (Кадет → Сарбаз → Батыр → Аксакал)
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _profile.evolutionTier.title.toUpperCase(),
                                        style: TextStyle(
                                          color: _profile.evolutionTier.auraColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _profile.evolutionTier.auraColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'СТУПЕНЬ ${_profile.evolutionTier.index + 1}/4',
                                          style: TextStyle(
                                            color: _profile.evolutionTier.auraColor,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Уровень ${_profile.level} · ${_profile.evolutionTier.ornamentName}',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${_profile.currentXp} / ${_profile.maxXp} XP',
                                style: TextStyle(
                                  color: AppColors.fg,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            _profile.evolutionTier.description,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: _profile.progressRatio,
                              backgroundColor: AppColors.raised,
                              valueColor: AlwaysStoppedAnimation<Color>(_profile.evolutionTier.auraColor),
                              minHeight: 5,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                progress.nextTier != null
                                    ? 'До звания ${progress.nextTier!.shortName}: ${progress.xpToNextTier} XP'
                                    : 'Максимальный легендарный ранг',
                                style: TextStyle(
                                  color: _profile.evolutionTier.auraColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              InkWell(
                                onTap: _showEvolutionTiersSheet,
                                child: const Text(
                                  'Все ступени эволюции >',
                                  style: TextStyle(
                                    color: AppColors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 10),

                    // 5. Статус ЦНС (бодрый или отдых)
                    GlassCard(
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _profile.state.badgeColor,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profile.state.title,
                                  style: TextStyle(
                                    color: _profile.state.badgeColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  _profile.state.description,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 14),

                    // 6. Полноценный чек-лист задач
                    _buildDailyQuestsChecklist(),

                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
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
