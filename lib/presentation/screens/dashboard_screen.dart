import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/intelligence/readiness_engine.dart';
import '../../domain/intelligence/sleep_engine.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/readiness.dart';
import '../../domain/models/telemetry.dart';
import '../widgets/circa_calibration_card.dart';
import '../widgets/circa_morning_briefing_dialog.dart';
import '../widgets/circa_morning_peak_banner.dart';
import '../widgets/circa_readiness_ring.dart';
import '../widgets/circa_recovery_breakdown_sheet.dart';
import '../widgets/circa_share_sheet.dart';
import '../widgets/circa_strain_milestone_badge.dart';
import '../widgets/glass_card.dart';
import '../widgets/live_pulse_wave.dart';
import 'private_league_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UteBleBridge bleBridge;
  final VoidCallback onOpenAvatar;
  final VoidCallback? onOpenDeviceSettings;

  const DashboardScreen({
    super.key,
    required this.bleBridge,
    required this.onOpenAvatar,
    this.onOpenDeviceSettings,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late BleTelemetry _telemetry;
  final PersonalBaseline _baseline = const PersonalBaseline();
  String _userName = 'Искандер';

  @override
  void initState() {
    super.initState();
    _telemetry = widget.bleBridge.currentTelemetry;
    _loadProfileName();

    widget.bleBridge.telemetryStream.listen((data) {
      if (mounted) {
        setState(() {
          _telemetry = data;
        });
      }
    });
  }

  Future<void> _loadProfileName() async {
    try {
      final p = await UserProfileRepository.loadProfile();
      if (mounted && p.name.isNotEmpty) {
        setState(() => _userName = p.name);
      }
    } catch (_) {}
  }

  String _getWeekdayName() {
    const weekdays = [
      'понедельник',
      'вторник',
      'среда',
      'четверг',
      'пятница',
      'суббота',
      'воскресенье',
    ];
    final now = DateTime.now();
    return weekdays[(now.weekday - 1).clamp(0, 6)];
  }

  void _triggerPulseMeasurement() {
    CircaHaptics.ringZoneTick();
    widget.bleBridge.triggerHeartRateMeasurement();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.rose, width: 1.0),
          ),
          content: Row(
            children: [
              const Icon(Icons.favorite, color: AppColors.rose, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppStrings.tr('today_pulse_measuring'),
                  style: const TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final readiness = ReadinessEngine.calculate(_telemetry, baseline: _baseline);
    final avatarProfile = AvatarManager.getProfile(_telemetry, baseline: _baseline);
    final strainResult = StrainEngine.evaluate(
      currentStrain: _telemetry.currentDayStrain,
      recoveryZone: readiness.zone,
      zoneMinutes: _telemetry.zoneMinutes,
    );
    final sleepResult = SleepEngine.calculate(telemetry: _telemetry, baseline: _baseline);
    final directiveAnalysis = AvatarManager.getDirectiveContrastQuote(
      recoveryScore: readiness.score,
      currentStrain: _telemetry.currentDayStrain,
      targetStrainMin: strainResult.targetStrainMin,
      targetStrainMax: strainResult.targetStrainMax,
      state: avatarProfile.state,
    );
    final barysQuote = directiveAnalysis.quote;
    final directiveType = directiveAnalysis.directiveType;
    final weekdayName = _getWeekdayName();

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        return Scaffold(
          backgroundColor: AppColors.stage,
          body: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. Фирменный хедер CIRCA ONE: Голова Барыса в кольце готовности + Приветствие
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                    child: Row(
                      children: [
                        // Аватар Барыса в кольце зоны готовности
                        GestureDetector(
                          onTap: widget.onOpenAvatar,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: readiness.zone.color,
                                width: 2.0,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                avatarProfile.state.assetPath,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Приветствие и день недели
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CIRCA ONE',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.2,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                language == AppLanguage.kyrgyz
                                    ? 'Салам, $_userName · $weekdayName'
                                    : 'Привет, $_userName · $weekdayName',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.fg,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Правые контролы: Утренний брифинг + Поделиться + Заряд
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.wb_sunny_outlined, color: AppColors.amber, size: 20),
                          tooltip: 'Утренний отчёт 07:00',
                          onPressed: () => CircaMorningBriefingDialog.show(context, _telemetry, _baseline),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.ios_share, color: AppColors.fg, size: 19),
                          tooltip: 'Поделиться днем',
                          onPressed: () => CircaShareSheet.show(
                            context,
                            telemetry: _telemetry,
                            baseline: _baseline,
                            userName: _userName,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: widget.onOpenDeviceSettings,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.raised,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.battery_std, size: 14, color: AppColors.sage),
                                const SizedBox(width: 4),
                                Text(
                                  '${_telemetry.batteryLevel}%',
                                  style: const TextStyle(
                                    color: AppColors.fg,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Утренний «пик» (выезжает сверху с Haptic-волной при входе)
                SliverToBoxAdapter(
                  child: CircaMorningPeakBanner(
                    telemetry: _telemetry,
                    baseline: _baseline,
                    recoveryScore: readiness.score,
                  ),
                ),

                // 3. Главный показатель 1: ВОССТАНОВЛЕНИЕ (Recovery Ring Card)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    child: GestureDetector(
                      onTap: () => CircaRecoveryBreakdownSheet.show(
                        context,
                        readiness,
                        telemetry: _telemetry,
                        baseline: _baseline,
                        userName: _userName,
                      ),
                      child: GlassCard(
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                        child: Column(
                          children: [
                            CircaReadinessRing(
                              score: readiness.score,
                              zone: readiness.zone,
                              size: 200,
                            ),
                            // Стрик-двигатель (монохромная пиктограмма звена цепи)
                            Container(
                              margin: const EdgeInsets.only(top: 10, bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (readiness.zone == RecoveryZone.optimal ? AppColors.sage : AppColors.amber).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (readiness.zone == RecoveryZone.optimal ? AppColors.sage : AppColors.amber).withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.link,
                                    size: 13,
                                    color: readiness.zone == RecoveryZone.optimal ? AppColors.sage : AppColors.amber,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    AppStrings.tr('today_streak_badge', language),
                                    style: TextStyle(
                                      color: readiness.zone == RecoveryZone.optimal ? AppColors.sage : AppColors.amber,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 3 ключевые метрики входа
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildMetricChip(AppStrings.tr('today_hrv', language), '${_telemetry.hrv.round()} мс'),
                                const SizedBox(width: 8),
                                Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.faint)),
                                const SizedBox(width: 8),
                                _buildMetricChip(AppStrings.tr('today_rhr', language), '${_telemetry.restingHeartRate} bpm'),
                                const SizedBox(width: 8),
                                Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.faint)),
                                const SizedBox(width: 8),
                                _buildMetricChip(AppStrings.tr('today_skin_temp', language), '${_telemetry.skinTempDeviation >= 0 ? '+' : ''}${_telemetry.skinTempDeviation.toStringAsFixed(1)} °C'),
                              ],
                            ),
                        const SizedBox(height: 16),

                        // Магнитный акцентный блок: Разбор 5 факторов (Основной 2-й тап дня)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.raised,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.sage.withValues(alpha: 0.15),
                                  border: Border.all(color: AppColors.sage.withValues(alpha: 0.4)),
                                ),
                                child: const Icon(Icons.auto_graph_outlined, size: 16, color: AppColors.sage),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppStrings.tr('today_5factors_title', language),
                                      style: const TextStyle(
                                        color: AppColors.fg,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      language == AppLanguage.kyrgyz
                                          ? 'Эмне үчүн бүгүн ${readiness.score}%? ЖЖВ, уйку жана температура талдоосу'
                                          : 'Почему сегодня ${readiness.score}%? Анализ ВСР, сна и температуры',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 18, color: AppColors.amber),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Вспомогательный шеринг
                        Align(
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () => CircaShareSheet.show(
                              context,
                              telemetry: _telemetry,
                              baseline: _baseline,
                              userName: _userName,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.ios_share, size: 12, color: AppColors.faint),
                                  SizedBox(width: 5),
                                  Text(
                                    'Поделиться днем',
                                    style: TextStyle(
                                      color: AppColors.faint,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 4. Главный показатель 2: НАГРУЗКА (Daily Strain Card)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Push-стильная вспышка микро-события выполнения Strain-бюджета («78% взято. Барыс одобряет»)
                    CircaStrainMilestoneBadge(
                      currentStrain: _telemetry.currentDayStrain,
                      targetStrainMin: strainResult.targetStrainMin,
                      targetStrainMax: strainResult.targetStrainMax,
                    ),
                    GlassCard(
                      borderRadius: 20,
                      padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'НАГРУЗКА ДНЯ',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                            ),
                          ),
                          Text(
                            'Цель: ${strainResult.targetStrainMin.toStringAsFixed(1)}–${strainResult.targetStrainMax.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _telemetry.currentDayStrain.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppColors.amber,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const Text(
                            ' / 21.0',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            strainResult.budgetStatusText,
                            style: TextStyle(
                              color: strainResult.isInTargetZone ? AppColors.sage : AppColors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_telemetry.currentDayStrain / 21.0).clamp(0.0, 1.0),
                          backgroundColor: AppColors.raised,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.amber),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

            // 5. Главный показатель 3: СОН И РИТУАЛ (Barys Ritual Quote & Bedtime)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: GlassCard(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'СОН И РИТУАЛ',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (directiveType.contains('ПРОВОКАЦИЯ')
                                          ? AppColors.amber
                                          : (directiveType.contains('ЗАБОТА') ? AppColors.rose : AppColors.sage))
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  directiveType,
                                  style: TextStyle(
                                    color: directiveType.contains('ПРОВОКАЦИЯ')
                                        ? AppColors.amber
                                        : (directiveType.contains('ЗАБОТА') ? AppColors.rose : AppColors.sage),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Отбой: ${sleepResult.optimalBedtime}',
                            style: const TextStyle(
                              color: AppColors.sage,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        barysQuote,
                        style: const TextStyle(
                          color: AppColors.fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.raised,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ФАКТ / NEED',
                                    style: TextStyle(color: AppColors.faint, fontSize: 9, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${sleepResult.actualSleepMinutes ~/ 60}ч ${sleepResult.actualSleepMinutes % 60}м / ${sleepResult.sleepNeedMinutes ~/ 60}ч ${sleepResult.sleepNeedMinutes % 60}м',
                                    style: const TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.raised,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'КАЧЕСТВО СНА',
                                    style: TextStyle(color: AppColors.faint, fontSize: 9, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${sleepResult.sleepPerformanceScore}% покрытия',
                                    style: const TextStyle(color: AppColors.sage, fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 6. Прогресс-карточка первой калибровки (Commitment Device: «База формируется: день 1/14»)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: CircaCalibrationCard(
                  currentDay: _baseline.calibrationDaysDone,
                  totalDays: 14,
                ),
              ),
            ),

            // 7. Круг доверия CIRCA (Приватная лига 3-5 друзей)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: GestureDetector(
                  onTap: () {
                    CircaHaptics.ringZoneTick();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PrivateLeagueScreen(bleBridge: widget.bleBridge),
                      ),
                    );
                  },
                  child: GlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shield_outlined, color: AppColors.amber, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  AppStrings.tr('today_league_card_title', language),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                AppStrings.trParams('league_slots_format', {'current': 4, 'max': 5}, language),
                                style: const TextStyle(
                                  color: AppColors.amber,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildFriendAvatarChip('ДС', 'Даурен', 86, AppColors.sage),
                            _buildFriendAvatarChip('АМ', 'Алия', 68, AppColors.amber),
                            _buildFriendAvatarChip('ТК', 'Тимур', 92, AppColors.sage),
                            _buildFriendAvatarChip('ВЫ', 'Вы', readiness.score, readiness.zone.color),
                            _buildAddFriendSlotChip(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(height: 1, color: AppColors.line),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Ср. баланс круга: 81% · Зеленый коридор',
                              style: TextStyle(
                                color: AppColors.faint,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Вся лига',
                                  style: TextStyle(
                                    color: AppColors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.amber),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 8. Живой пульс в реальном времени с волной (интерактивный замер)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: GestureDetector(
                  onTap: _triggerPulseMeasurement,
                  child: GlassCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.rose,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppStrings.tr('today_live_pulse', language),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${_telemetry.heartRate}',
                                  style: const TextStyle(
                                    color: AppColors.fg,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                                const Text(
                                  ' bpm',
                                  style: TextStyle(
                                    color: AppColors.rose,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 48,
                          child: LivePulseWaveWidget(
                            bpm: _telemetry.heartRate,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(height: 1, color: AppColors.line),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              language == AppLanguage.kyrgyz
                                  ? 'Вариабелдүүлүк: ${_telemetry.hrv.round()} мс · Ченемде'
                                  : 'Вариабельность: ${_telemetry.hrv.round()} мс · В норме',
                              style: const TextStyle(
                                color: AppColors.faint,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  AppStrings.tr('today_trigger_pulse', language),
                                  style: const TextStyle(
                                    color: AppColors.rose,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.rose),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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

  Widget _buildMetricChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.fg,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildFriendAvatarChip(String initials, String name, int score, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: color, width: 1.8),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.stage,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color, width: 0.8),
              ),
              child: Text(
                '$score%',
                style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(color: AppColors.fg, fontSize: 10.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildAddFriendSlotChip() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: AppColors.line, width: 1.2),
          ),
          child: const Center(
            child: Icon(Icons.add, color: AppColors.faint, size: 16),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '+Друг',
          style: TextStyle(color: AppColors.faint, fontSize: 10.5, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
