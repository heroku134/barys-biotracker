import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/app_typography.dart';
import '../../core/avatar_image_provider.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/services/ios_widget_service.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/intelligence/readiness_engine.dart';
import '../../domain/intelligence/sleep_engine.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/telemetry.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/circa_avatar_picker_dialog.dart';
import '../widgets/circa_recovery_breakdown_sheet.dart';
import '../widgets/circa_readiness_ring.dart';
import '../widgets/circa_strain_card.dart';
import '../widgets/circa_hypnogram.dart';
import '../widgets/kalkan_ui.dart';
import '../widgets/kalkan_chrome.dart';
import '../widgets/circa_cycle_card.dart';
import 'menstrual_cycle_screen.dart';
import 'pregnancy_screen.dart';
import '../../domain/intelligence/day_copy.dart';
import '../../data/storage/calibration_store.dart';
import '../../data/storage/day_snapshot_repository.dart';
import '../../data/storage/local_day_strain.dart';
import '../../data/storage/climate_mode_store.dart';
import '../../data/storage/partner_cycle_repository.dart';
import '../../domain/models/partner_cycle_data.dart';
import '../widgets/circa_partner_cycle_card.dart';
import '../widgets/circa_partner_cycle_sheet.dart';
import '../../domain/intelligence/yesterday_miss.dart';
import '../../data/services/reminder_service.dart';
import '../../data/services/paired_pulse.dart';
import '../../data/services/system_notification_service.dart';

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
  PersonalBaseline _baseline = const PersonalBaseline();
  ReminderKind? _banner;
  String? _miss;
  ClimateMode _climate = ClimateMode.normal;
  UserProfile _userProfile = const UserProfile();
  PartnerCycleData? _partner;
  StreamSubscription<BleTelemetry>? _sub;
  int _calDays = 14;

  @override
  void initState() {
    super.initState();
    _telemetry = widget.bleBridge.currentTelemetry;
    _loadProfile();
    _loadCal();
    _partner = PartnerCycleRepository.notifier.value;
    PartnerCycleRepository.notifier.addListener(_onPartnerNotifier);
    _syncIosWidgets();
    UserProfileRepository.profileNotifier.addListener(_onProfileNotifier);
    _sub = widget.bleBridge.telemetryStream.listen((data) {
      if (!mounted) return;
      setState(() => _telemetry = data);
      _syncIosWidgets();
      if (data.hasNightData && data.hasHrv && data.hasRhr && !data.isOffWrist) {
        _recordTelemetryCalibration(data);
      }
    });
  }

  Future<void> _recordTelemetryCalibration(BleTelemetry data) async {
    if (!data.hasNightData || !data.hasHrv || !data.hasRhr || data.isOffWrist) return;
    final recorded = await CalibrationStore.recordMorningSync(
      hrv: data.hrv,
      rhr: data.restingHeartRate,
    );
    if (recorded && mounted) {
      final b = await CalibrationStore.loadBaseline();
      setState(() {
        _baseline = b;
        _calDays = b.calibrationDaysDone;
      });
      _syncIosWidgets();
    }
  }

  void _onPartnerNotifier() {
    if (mounted) {
      setState(() => _partner = PartnerCycleRepository.notifier.value);
    }
  }

  void _onProfileNotifier() {
    if (mounted) {
      setState(() => _userProfile = UserProfileRepository.profileNotifier.value);
    }
  }

  void _syncIosWidgets() {
    final readiness = ReadinessEngine.calculate(_telemetry, baseline: _baseline);
    final fromWatch = _telemetry.currentDayStrain > 0
        ? _telemetry.currentDayStrain
        : (_telemetry.zoneMinutes.any((m) => m > 0)
            ? StrainEngine.calculateStrainFromZones(_telemetry.zoneMinutes)
            : StrainEngine.calculateDailyActivityStrain(
                activeCalories: _telemetry.calories,
                steps: _telemetry.steps,
              ));
    final reconciledStrain = math.max(fromWatch, LocalDayStrain.current());
    final strain = StrainEngine.evaluate(currentStrain: reconciledStrain, recoveryZone: readiness.zone);
    final sleep = SleepEngine.analyze(_telemetry);
    final hasNight = _telemetry.sleepMinutes > 0 || _telemetry.hrv > 0;
    final line = DayCopy.morning(
      sleepScore: sleep.sleepPerformanceScore,
      tMin: strain.targetStrainMin,
      tMax: strain.targetStrainMax,
      miss: _miss,
      climate: _climate,
    );
    IosWidgetService.updateWidgets(
      telemetry: _telemetry,
      readiness: readiness,
      currentStrain: reconciledStrain,
      targetStrainMax: strain.targetStrainMax,
      sleepScore: sleep.sleepPerformanceScore,
      morningLine: line,
      calibrationDay: _calDays,
      hasNightData: hasNight,
    );
    SystemNotificationService.refreshFromDay(
      recovery: readiness.score,
      targetMin: strain.targetStrainMin,
      targetMax: strain.targetStrainMax,
      strainNow: reconciledStrain,
      sleepMinutes: _telemetry.sleepMinutes,
      hrv: _telemetry.hrv,
      baselineHrv: _baseline.meanHrv,
      yesterdayMiss: _miss,
      hasNightData: hasNight,
      isOffWrist: _telemetry.isOffWrist,
      calibrationDay: _calDays,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    UserProfileRepository.profileNotifier.removeListener(_onProfileNotifier);
    PartnerCycleRepository.notifier.removeListener(_onPartnerNotifier);
    super.dispose();
  }

  Future<void> _loadCal() async {
    if (_telemetry.hasNightData && _telemetry.hasHrv && _telemetry.hasRhr && !_telemetry.isOffWrist) {
      await CalibrationStore.recordMorningSync(
        hrv: _telemetry.hrv,
        rhr: _telemetry.restingHeartRate,
      );
    }
    final b = await CalibrationStore.loadBaseline();
    final kind = ReminderService.activeBanner();
    var show = kind;
    if (kind != null && !await ReminderService.shouldShow(kind)) show = null;
    await DaySnapshotRepository.seedPreviewIfEmpty(_telemetry);
    final rec = ReadinessEngine.calculate(_telemetry, baseline: b);
    await DaySnapshotRepository.recordTelemetry(
      _telemetry,
      recovery: rec.score,
      sleep: SleepEngine.calculate(telemetry: _telemetry, baseline: b).sleepPerformanceScore,
    );
    final miss = await YesterdayMiss.line(ru: AppLocaleNotifier.current != AppLanguage.english, en: 'Sleep or strain slipped yesterday.');
    final climate = await ClimateModeStore.load();
    if (mounted) {
      setState(() {
        _baseline = b;
        _calDays = b.calibrationDaysDone;
        _banner = show;
        _miss = miss;
        _climate = climate;
      });
    }
    await PairedPulse.morningIfNeeded(widget.bleBridge);
  }

  Future<void> _loadProfile() async {
    try {
      final p = await UserProfileRepository.loadProfile();
      if (mounted) setState(() => _userProfile = p);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final language = AppLocaleNotifier.current;
    final readiness = ReadinessEngine.calculate(_telemetry, baseline: _baseline);

    final fromWatch = _telemetry.currentDayStrain > 0
        ? _telemetry.currentDayStrain
        : (_telemetry.zoneMinutes.any((m) => m > 0)
            ? StrainEngine.calculateStrainFromZones(_telemetry.zoneMinutes)
            : StrainEngine.calculateDailyActivityStrain(
                activeCalories: _telemetry.calories,
                steps: _telemetry.steps,
              ));
    final currentStrain = math.max(fromWatch, LocalDayStrain.current());
    final strainResult = StrainEngine.evaluate(
      currentStrain: currentStrain,
      recoveryZone: readiness.zone,
      zoneMinutes: _telemetry.zoneMinutes,
      climateFactor: ClimateModeStore.strainFactor(_climate),
    );
    final sleepResult = SleepEngine.calculate(telemetry: _telemetry, baseline: _baseline);
    final sleepScore = sleepResult.sleepPerformanceScore;
    final name = _userProfile.name.isNotEmpty ? _userProfile.name : AppStrings.tr('home_guest', language);
    final isConnected = _telemetry.isConnected;
    final hasNightData = readiness.hasSufficientData;
    final isCalibrating = _calDays < 14;

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: KalkanAppBar(
        eyebrow: AppStrings.tr('nav_today', language),
        title: name,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: GestureDetector(
              onTap: () {
                CircaHaptics.selectionClick();
                CircaAvatarPickerDialog.show(context, _userProfile);
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.hairline, width: KalkanUi.hairline),
                ),
                child: ClipOval(
                  child: AvatarImageProvider.buildAvatarWidget(path: _userProfile.avatarPath),
                ),
              ),
            ),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              CircaHaptics.selectionClick();
              widget.onOpenDeviceSettings?.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                border: Border.all(color: palette.hairline, width: KalkanUi.hairline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isConnected ? palette.fg : AppColors.rose,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isConnected && _telemetry.batteryLevel > 0) ...[
                    if (_telemetry.isCharging) ...[
                      const Icon(Icons.battery_charging_full, size: 13, color: AppColors.amber),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      '${_telemetry.batteryLevel}%',
                      style: AppTypography.caption(
                        _telemetry.isCharging ? AppColors.amber : palette.secondary,
                      ),
                    ),
                  ] else ...[
                    Text(
                      isConnected
                          ? AppStrings.tr('home_synced', language)
                          : AppStrings.tr('home_offline', language),
                      style: AppTypography.caption(
                        isConnected ? palette.secondary : AppColors.rose,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            if (_banner != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(KalkanUi.pagePadding, 12, KalkanUi.pagePadding, 0),
                  child: KalkanCard(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _banner == ReminderKind.evening
                                ? AppLocaleNotifier.pick('Лечь до 22:30', '22:30га чейин уктоо', 'Sleep before 22:30')
                                : AppLocaleNotifier.pick('Восстановление готово', 'Калыбына келүү даяр', 'Recovery score ready'),
                            style: AppTypography.bodySemibold(palette.fg),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await ReminderService.dismiss(_banner!);
                            if (!mounted) return;
                            setState(() => _banner = null);
                          },
                          child: Text(AppLocaleNotifier.pick('Ок', 'Макул', 'OK'), style: TextStyle(color: AppColors.sage)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (!isConnected)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(KalkanUi.pagePadding, 10, KalkanUi.pagePadding, 0),
                  child: KalkanCard(
                    padding: const EdgeInsets.all(14),
                    borderColor: AppColors.amber.withValues(alpha: 0.4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                          ),
                          child: const Icon(Icons.watch_off_outlined, color: AppColors.amber, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocaleNotifier.pick('СААТ-1 НЕ НА СВЯЗИ', 'СААТ-1 ТУТАШКАН ЭМЕС', 'SAAT-1 DISCONNECTED'),
                                style: AppTypography.eyebrow(AppColors.amber),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppLocaleNotifier.pick(
                                  'Связь с часами отсутствует. Данные не обновляются.',
                                  'Саат менен байланыш жок. Маалыматтар жаңыртылбайт.',
                                  'Watch connection lost. Metrics not updating.',
                                ),
                                style: AppTypography.caption(palette.secondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            CircaHaptics.selectionClick();
                            widget.onOpenDeviceSettings?.call();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.amber,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          child: Text(
                            AppLocaleNotifier.pick('Подключить', 'Туташтыруу', 'Connect'),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(KalkanUi.pagePadding, 16, KalkanUi.pagePadding, 0),
                child: Column(
                  children: [
                    // 1. Hero Ring: Recovery 0–100, 190px, flat arc, zone color
                    Center(
                      child: CircaReadinessRing(
                        score: hasNightData ? readiness.score : 0,
                        zone: readiness.zone,
                        size: 190,
                        label: AppStrings.tr('home_recovery', language),
                        onTap: () {
                          CircaHaptics.selectionClick();
                          CircaRecoveryBreakdownSheet.show(
                            context,
                            readiness,
                            telemetry: _telemetry,
                            baseline: _baseline,
                            userName: name,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. Two clickable satellites: Sleep (Left) & Strain (Right)
                    Row(
                      children: [
                        Expanded(
                          child: _satelliteCard(
                            palette: palette,
                            title: AppStrings.tr('home_sleep', language),
                            value: hasNightData ? '$sleepScore%' : '—',
                            subtext: hasNightData
                                ? '${_telemetry.sleepMinutes ~/ 60}ч ${_telemetry.sleepMinutes % 60}м'
                                : AppLocaleNotifier.pick('Нет данных', 'Маалымат жок', 'No data'),
                            accentColor: AppColors.sleepBlue,
                            onTap: () {
                              CircaHaptics.selectionClick();
                              CircaHypnogram.showSleepBreakdownSheet(context, sleepResult);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _satelliteCard(
                            palette: palette,
                            title: AppStrings.tr('home_strain', language),
                            value: currentStrain.toStringAsFixed(1),
                            subtext: '${AppLocaleNotifier.pick('Цель', 'Максат', 'Target')} ${strainResult.targetStrainMax.toStringAsFixed(1)}',
                            accentColor: AppColors.strainBlue,
                            onTap: () {
                              CircaHaptics.selectionClick();
                              _showStrainSheet(context, strainResult);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 3. One clear actionable sentence (DayCopy)
                    KalkanCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: readiness.zone.color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              hasNightData
                                  ? DayCopy.morning(
                                      sleepScore: sleepScore,
                                      tMin: strainResult.targetStrainMin,
                                      tMax: strainResult.targetStrainMax,
                                      miss: _miss,
                                      climate: _climate,
                                    )
                                  : AppLocaleNotifier.pick(
                                      'Ночь без данных СААТ-1 · Носите часы перед сном для точного расчёта восстановления.',
                                      'СААТ-1 түнкү маалыматы жок · Калыбына келүүнү эсептөө үчүн саатты тагыңыз.',
                                      'Night without SAAT-1 data · Wear watch overnight for calibrated recovery.',
                                    ),
                              style: AppTypography.body(palette.fg).copyWith(
                                height: 1.4,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Calibration progress indicator (discreet hairline, only when < 14 days)
            if (isCalibrating)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(KalkanUi.pagePadding, 10, KalkanUi.pagePadding, 0),
                  child: KalkanCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Text(
                          AppLocaleNotifier.pick('Калибровка $_calDays/14 дней', 'Калибрлөө $_calDays/14 күн', 'Calibration $_calDays/14 days'),
                          style: AppTypography.caption(palette.secondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(KalkanUi.progressRadius),
                            child: LinearProgressIndicator(
                              value: (_calDays / 14.0).clamp(0.0, 1.0),
                              backgroundColor: palette.raised,
                              valueColor: AlwaysStoppedAnimation<Color>(palette.secondary),
                              minHeight: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 5. 0–21 Strain Corridor Card with heart rate zones
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(KalkanUi.pagePadding, 12, KalkanUi.pagePadding, 0),
                child: CircaStrainCard(
                  strainResult: strainResult,
                  onOpenWorkout: () {},
                ),
              ),
            ),

            // 6. Female cycle or linked partner cycle card
            if (_userProfile.gender == Gender.female)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(KalkanUi.pagePadding, 12, KalkanUi.pagePadding, 0),
                  child: CircaCycleCard(
                    telemetry: _telemetry,
                    profile: _userProfile,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _userProfile.isPregnant
                            ? PregnancyScreen(bleBridge: widget.bleBridge)
                            : MenstrualCycleScreen(bleBridge: widget.bleBridge),
                      ),
                    ),
                  ),
                ),
              ),
            if (_userProfile.gender != Gender.female && _partner != null && _partner!.isLinked)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(KalkanUi.pagePadding, 12, KalkanUi.pagePadding, 0),
                  child: CircaPartnerCycleCard(
                    data: _partner!,
                    onTap: () => CircaPartnerCycleSheet.show(context, _partner!),
                  ),
                ),
              ),

            // 7. Compact single-row telemetry strip at bottom
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(KalkanUi.pagePadding, 12, KalkanUi.pagePadding, 32),
                child: GestureDetector(
                  onTap: () {
                    CircaHaptics.selectionClick();
                    CircaRecoveryBreakdownSheet.show(
                      context,
                      readiness,
                      telemetry: _telemetry,
                      baseline: _baseline,
                      userName: name,
                    );
                  },
                  child: KalkanCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        _miniStat(palette, 'HRV', _telemetry.hrv > 0 ? '${_telemetry.hrv.round()}' : '—', 'ms'),
                        _statDivider(palette),
                        _miniStat(palette, AppLocaleNotifier.pick('Покой', 'Тынч', 'RHR'), _telemetry.restingHeartRate > 0 ? '${_telemetry.restingHeartRate}' : '—', 'bpm'),
                        _statDivider(palette),
                        _miniStat(palette, 'SpO2', _telemetry.hasBloodOxygen ? '${_telemetry.bloodOxygen}%' : '—', ''),
                        _statDivider(palette),
                        _miniStat(palette, AppLocaleNotifier.pick('Кожа', 'Тери', 'Temp'), _telemetry.hasSkinTempDeviation ? '${_telemetry.skinTempDeviation >= 0 ? "+" : ""}${_telemetry.skinTempDeviation.toStringAsFixed(1)}°' : '—', ''),
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
  }

  void _showStrainSheet(BuildContext context, StrainCalculationResult strainResult) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final palette = KalkanColors.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(KalkanUi.cardRadius)),
            border: Border(top: BorderSide(color: palette.hairline, width: KalkanUi.hairline)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.hairline,
                    borderRadius: BorderRadius.circular(KalkanUi.progressRadius),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CircaStrainCard(strainResult: strainResult),
            ],
          ),
        );
      },
    );
  }

  Widget _satelliteCard({
    required KalkanColors palette,
    required String title,
    required String value,
    required String subtext,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: KalkanCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTypography.heroNumberMedium(palette.fg).copyWith(
                fontSize: 26,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtext,
              style: AppTypography.caption(palette.secondary).copyWith(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(KalkanColors palette, String label, String value, String unit) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption(palette.secondary).copyWith(fontSize: 10)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppTypography.metricValue(palette.fg).copyWith(fontSize: 15)),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(unit, style: AppTypography.caption(palette.muted).copyWith(fontSize: 9)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _statDivider(KalkanColors palette) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: palette.hairline,
    );
  }
}
