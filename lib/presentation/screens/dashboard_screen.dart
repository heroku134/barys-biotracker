import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/intelligence/readiness_engine.dart';
import '../../domain/intelligence/sleep_engine.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/readiness.dart';
import '../../domain/models/telemetry.dart';
import '../widgets/circa_3d_recovery_orb.dart';
import '../widgets/circa_avatar_picker_dialog.dart';
import '../widgets/circa_calibration_card.dart';
import '../widgets/circa_recovery_breakdown_sheet.dart';
import '../widgets/circa_share_sheet.dart';
import '../widgets/circa_hypnogram.dart';
import '../widgets/circa_friend_detail_sheet.dart';
import '../widgets/glass_card.dart';
import '../widgets/live_pulse_wave.dart';
import 'private_league_screen.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/private_league.dart';
import '../widgets/circa_cycle_card.dart';
import '../widgets/circa_partner_cycle_card.dart';
import '../widgets/circa_partner_cycle_sheet.dart';
import '../../domain/models/partner_cycle_data.dart';
import '../../data/storage/partner_cycle_repository.dart';
import '../../data/storage/private_league_repository.dart';
import 'menstrual_cycle_screen.dart';

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
  UserProfile _userProfile = const UserProfile();
  PrivateLeague? _league;
  PartnerCycleData? _partnerCycle;

  @override
  void initState() {
    super.initState();
    _telemetry = widget.bleBridge.currentTelemetry;
    _loadProfile();
    _loadLeague();
    _loadPartnerCycle();
    UserProfileRepository.profileNotifier.addListener(_onProfileChanged);
    PartnerCycleRepository.notifier.addListener(_onPartnerCycleChanged);

    widget.bleBridge.telemetryStream.listen((data) {
      if (mounted) {
        setState(() {
          _telemetry = data;
        });
        _loadLeague();
      }
    });
  }

  void _onProfileChanged() {
    if (mounted) {
      setState(() {
        _userProfile = UserProfileRepository.profileNotifier.value;
        if (_userProfile.name.isNotEmpty) _userName = _userProfile.name;
      });
      _loadLeague();
    }
  }

  void _onPartnerCycleChanged() {
    if (mounted) {
      setState(() {
        _partnerCycle = PartnerCycleRepository.notifier.value;
      });
    }
  }

  @override
  void dispose() {
    UserProfileRepository.profileNotifier.removeListener(_onProfileChanged);
    PartnerCycleRepository.notifier.removeListener(_onPartnerCycleChanged);
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await UserProfileRepository.loadProfile();
      if (mounted) {
        setState(() {
          _userProfile = p;
          if (p.name.isNotEmpty) _userName = p.name;
        });
        _loadLeague();
      }
    } catch (_) {}
  }

  Future<void> _loadPartnerCycle() async {
    try {
      final p = await PartnerCycleRepository.loadPartnerCycle();
      if (mounted) {
        setState(() {
          _partnerCycle = p;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadLeague() async {
    try {
      final l = await PrivateLeagueRepository.loadLeague(
        telemetry: _telemetry,
        profile: _userProfile,
      );
      if (mounted) {
        setState(() {
          _league = l;
        });
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
    final strainResult = StrainEngine.evaluate(
      currentStrain: _telemetry.currentDayStrain,
      recoveryZone: readiness.zone,
      zoneMinutes: _telemetry.zoneMinutes,
    );
    final sleepResult = SleepEngine.calculate(telemetry: _telemetry, baseline: _baseline);
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
                // 1. Фирменный хедер CIRCA ONE: Аватар владельца + Приветствие
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                    child: Row(
                      children: [
                        // Аватар владельца с вызовом диалога загрузки / смены фото
                        GestureDetector(
                          onTap: () => CircaAvatarPickerDialog.show(context, _userProfile),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: readiness.zone.color,
                                    width: 2.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: readiness.zone.color.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    _userProfile.avatarPath ?? 'assets/images/warrior_cutout_clean.png',
                                    fit: BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.surface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 10, color: AppColors.amber),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Приветствие: только имя и день недели (БЕЗ "КАЛКАН СПОРТ")
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                language == AppLanguage.kyrgyz
                                    ? 'Салам, $_userName'
                                    : 'Привет, $_userName',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.fg,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                weekdayName,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Главный показатель 1: ВОССТАНОВЛЕНИЕ (3D Biometric Orb Card)
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
                            Circa3DRecoveryOrb(
                              score: readiness.score,
                              zone: readiness.zone,
                              size: 215,
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

                            // 3 ключевые метрики входа (Понятные русские термины без ВСР / bpm)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildMetricChip('Ритм сердца', '${_telemetry.hrv.round()} мс'),
                                  const SizedBox(width: 8),
                                  Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.faint)),
                                  const SizedBox(width: 8),
                                  _buildMetricChip('Пульс покоя', '${_telemetry.restingHeartRate} уд/мин'),
                                  const SizedBox(width: 8),
                                  Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.faint)),
                                  const SizedBox(width: 8),
                                  _buildMetricChip('Температура', '${_telemetry.skinTempDeviation >= 0 ? '+' : ''}${_telemetry.skinTempDeviation.toStringAsFixed(1)} °C'),
                                ],
                              ),
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
                                          ? 'Эмне үчүн бүгүн ${readiness.score}%? Жүрөк ыргагы, уйку жана температура талдоосу'
                                          : 'Почему сегодня ${readiness.score}%? Анализ ритма сердца, сна и температуры',
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

            // 3.1 Карточка мониторинга женского цикла (СААТ-1 термосенсор) - только для девушек
            if (_userProfile.gender == Gender.female)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: CircaCycleCard(
                    telemetry: _telemetry,
                    profile: _userProfile,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MenstrualCycleScreen(bleBridge: widget.bleBridge),
                        ),
                      ).then((_) => _loadProfile());
                    },
                  ),
                ),
              ),

            // 3.2 Карточка биоритма партнёрши (Синхронизация цикла партнёра)
            if (_partnerCycle != null && _partnerCycle!.isLinked)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: CircaPartnerCycleCard(
                    data: _partnerCycle!,
                    onTap: () => CircaPartnerCycleSheet.show(context, _partnerCycle!),
                  ),
                ),
              ),

            // 4. Главный показатель 2: НАГРУЗКА (Daily Strain Card)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: GestureDetector(
                  onTap: () => _showStrainExplanationSheet(context, strainResult),
                  child: GlassCard(
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
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Кардио-нагрузка сердца (0–21)',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Зоны пульса',
                                  style: TextStyle(
                                    color: AppColors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios, size: 9, color: AppColors.amber),
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

            // 5. Главный показатель 3: СОН (Clean Sleep Card)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: GestureDetector(
                  onTap: () {
                    CircaHaptics.selectionClick();
                    CircaHypnogram.showSleepBreakdownSheet(context, sleepResult);
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
                            const Text(
                              'СОН',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.0,
                              ),
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${sleepResult.actualSleepMinutes ~/ 60}ч ${sleepResult.actualSleepMinutes % 60}м',
                              style: const TextStyle(
                                color: AppColors.fg,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.0,
                              ),
                            ),
                            Text(
                              ' / ${sleepResult.sleepNeedMinutes ~/ 60}ч ${sleepResult.sleepNeedMinutes % 60}м',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.sage.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.sage.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '${sleepResult.sleepPerformanceScore}% покрытия',
                                style: const TextStyle(
                                  color: AppColors.sage,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (sleepResult.actualSleepMinutes / sleepResult.sleepNeedMinutes).clamp(0.0, 1.0),
                            backgroundColor: AppColors.raised,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sage),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Глуб: ${(sleepResult.actualSleepMinutes * 0.22 / 60).toStringAsFixed(1)}ч · REM: ${(sleepResult.actualSleepMinutes * 0.24 / 60).toStringAsFixed(1)}ч',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Row(
                              children: const [
                                Text(
                                  'Анализ сна',
                                  style: TextStyle(
                                    color: AppColors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios, size: 9, color: AppColors.amber),
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

            // 6. Прогресс-карточка первой калибровки (Commitment Device: «База формируется: день 1/14»)
            if (_baseline.calibrationDaysDone < 14)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: CircaCalibrationCard(
                    currentDay: _baseline.calibrationDaysDone,
                    totalDays: 14,
                  ),
                ),
              ),

            // 7. Круг доверия KALKAN (Приватная лига 3-5 друзей)
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
                    ).then((_) => _loadLeague());
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
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.shield_outlined, color: AppColors.amber, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      AppStrings.tr('today_league_card_title', language),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '${_league?.members.length ?? 4}/${_league?.maxMembers ?? 5} мест',
                                style: const TextStyle(
                                  color: AppColors.amber,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Увеличенные и информативные аватары друзей с реальными данными из репозитория
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              if (_league != null)
                                ..._league!.members.map((m) => Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: _buildFriendMemberCard(m),
                                    ))
                              else ...[
                                _buildFriendAvatarChip('ДС', 'Даурен', 86, AppColors.sage),
                                const SizedBox(width: 12),
                                _buildFriendAvatarChip('АМ', 'Алия', 68, AppColors.amber),
                                const SizedBox(width: 12),
                                _buildFriendAvatarChip('ТК', 'Тимур', 92, AppColors.sage),
                                const SizedBox(width: 12),
                                _buildFriendAvatarChip('ВЫ', 'Вы', readiness.score, readiness.zone.color),
                              ],
                              if (_league == null || !_league!.isFull)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => PrivateLeagueScreen(bleBridge: widget.bleBridge),
                                        ),
                                      ).then((_) => _loadLeague());
                                    },
                                    child: _buildAddFriendSlotChip(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(height: 1, color: AppColors.line),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ср. баланс круга: ${(_league?.averageRecovery ?? 81).round()}% · Зеленый коридор',
                              style: const TextStyle(
                                color: AppColors.faint,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: const [
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

  Widget _buildFriendMemberCard(FriendMember member) {
    return GestureDetector(
      onTap: () {
        CircaFriendDetailSheet.show(context, member);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: member.recoveryZone.color, width: 2.0),
                ),
                child: Center(
                  child: Text(
                    member.avatarInitials,
                    style: TextStyle(
                      color: member.recoveryZone.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.stage,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: member.recoveryZone.color, width: 0.8),
                ),
                child: Text(
                  '${member.recoveryScore}%',
                  style: TextStyle(
                    color: member.recoveryZone.color,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            member.name.split(' ').first,
            style: const TextStyle(
              color: AppColors.fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddFriendSlotChip() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: AppColors.line, width: 1.5),
          ),
          child: const Center(
            child: Icon(Icons.person_add_alt_1_outlined, color: AppColors.amber, size: 18),
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '+Друг',
          style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _showStrainExplanationSheet(BuildContext context, StrainCalculationResult strainResult) {
    CircaHaptics.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'НАГРУЗКА ДНЯ (STRAIN 0–21)',
                      style: TextStyle(
                        color: AppColors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.muted, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Что означает показатель нагрузки?',
                  style: TextStyle(color: AppColors.fg, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Text(
                    'Шкала от 0 до 21 отражает общую работу сердечно-сосудистой системы за сутки. Она учитывает время нахождения в различных пульсовых зонах (от спокойной ходьбы до интервалов).',
                    style: TextStyle(color: AppColors.fg, fontSize: 13, height: 1.4),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'ПУЛЬСОВЫЕ ЗОНЫ СЕРДЦА:',
                  style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                _buildZoneRow('Зона 1: Восстановление (< 50% ЧСС)', AppColors.sage),
                _buildZoneRow('Зона 2: Сжигание жира (50–60% ЧСС)', AppColors.sage),
                _buildZoneRow('Зона 3: Аэробная выносливость (60–70% ЧСС)', AppColors.amber),
                _buildZoneRow('Зона 4: Анаэробный порог (70–80% ЧСС)', AppColors.amber),
                _buildZoneRow('Зона 5: Пиковая нагрузка (80–100% ЧСС)', AppColors.rose),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: AppColors.stage,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('ПОНЯТНО', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.0)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildZoneRow(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
