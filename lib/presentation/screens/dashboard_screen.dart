import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/date_format.dart';
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
import '../widgets/circa_calibration_card.dart';
import '../widgets/circa_recovery_breakdown_sheet.dart';
import '../widgets/metric_dial.dart';
import 'private_league_screen.dart';
import 'day_journal_screen.dart';
import '../widgets/mascot_face.dart';
import '../../domain/intelligence/day_copy.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../data/storage/calibration_store.dart';
import '../../data/storage/day_snapshot_repository.dart';
import '../../data/storage/local_day_strain.dart';
import '../../data/storage/climate_mode_store.dart';
import '../../data/storage/partner_cycle_repository.dart';
import '../../domain/models/partner_cycle_data.dart';
import '../widgets/circa_partner_cycle_card.dart';
import '../widgets/circa_partner_cycle_sheet.dart';
import '../widgets/glass_card.dart';
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
      if (data.hrv > 0) {
        _recordTelemetryCalibration(data);
      }
    });
  }

  Future<void> _recordTelemetryCalibration(BleTelemetry data) async {
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
    final strain = StrainEngine.evaluate(currentStrain: _telemetry.currentDayStrain, recoveryZone: readiness.zone);
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
      currentStrain: _telemetry.currentDayStrain > 0 ? _telemetry.currentDayStrain : 0,
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
      strainNow: _telemetry.currentDayStrain,
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
    await CalibrationStore.recordMorningSync(
      hrv: _telemetry.hrv,
      rhr: _telemetry.restingHeartRate,
    );
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
        : StrainEngine.calculateStrainFromZones(_telemetry.zoneMinutes);
    final currentStrain = fromWatch + LocalDayStrain.current();
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

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        CircaHaptics.selectionClick();
                        CircaAvatarPickerDialog.show(context, _userProfile);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.hairline),
                        ),
                        child: ClipOval(
                          child: AvatarImageProvider.buildAvatarWidget(path: _userProfile.avatarPath),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: AppTypography.bodySemibold(palette.fg)),
                          Text(
                            AppDates.formatLong(DateTime.now(), language),
                            style: AppTypography.caption(palette.secondary),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        CircaHaptics.selectionClick();
                        widget.onOpenDeviceSettings?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: palette.hairline),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isConnected ? AppColors.sage : AppColors.rose,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isConnected
                                  ? AppStrings.tr('home_synced', language)
                                  : AppStrings.tr('home_offline', language),
                              style: AppTypography.caption(
                                isConnected ? AppColors.sage : AppColors.rose,
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
            if (_banner != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.hairline),
                    ),
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
                            setState(() => _banner = null);
                          },
                          child: Text(AppLocaleNotifier.pick('Ок', 'Макул', 'OK'), style: TextStyle(color: AppColors.sage)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    MetricDial(
                      label: AppStrings.tr('home_sleep', language),
                      value: '$sleepScore%',
                      progress: sleepScore / 100,
                      color: AppColors.sleepBlue,
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
                    MetricDial(
                      label: AppStrings.tr('home_recovery', language),
                      value: '${readiness.score}%',
                      progress: readiness.score / 100,
                      color: readiness.zone.color,
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
                    MetricDial(
                      label: AppStrings.tr('home_strain', language),
                      value: currentStrain.toStringAsFixed(1),
                      progress: (currentStrain / 21).clamp(0.0, 1.0),
                      color: AppColors.strainBlue,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocaleNotifier.pick(
                          'Цель нагрузки сегодня  ${strainResult.targetStrainMin.toStringAsFixed(0)}–${strainResult.targetStrainMax.toStringAsFixed(1)}',
                          'Бүгүнкү жүктөм  ${strainResult.targetStrainMin.toStringAsFixed(0)}–${strainResult.targetStrainMax.toStringAsFixed(1)}',
                          'Target Strain Today  ${strainResult.targetStrainMin.toStringAsFixed(0)}–${strainResult.targetStrainMax.toStringAsFixed(1)}',
                        ),
                        style: AppTypography.bodySemibold(palette.fg),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (currentStrain / 21).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: palette.raised,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            strainResult.isInTargetZone ? AppColors.sage : (currentStrain > strainResult.targetStrainMax ? AppColors.rose : AppColors.strainBlue),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocaleNotifier.pick(
                          'Сейчас ${currentStrain.toStringAsFixed(1)} из 21. ${strainResult.budgetStatusText}.',
                          'Азыр ${currentStrain.toStringAsFixed(1)} / 21. ${strainResult.budgetStatusText}.',
                          'Currently ${currentStrain.toStringAsFixed(1)} of 21. ${strainResult.budgetStatusText}.',
                        ),
                        style: AppTypography.caption(palette.secondary).copyWith(height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MascotFace(
                            state: AvatarManager.calculateState(_telemetry, baseline: _baseline),
                            size: 56,
                            climate: _climate,
                            onTap: widget.onOpenAvatar,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              DayCopy.morning(
                                sleepScore: sleepScore,
                                tMin: strainResult.targetStrainMin,
                                tMax: strainResult.targetStrainMax,
                                miss: _miss,
                                climate: _climate,
                              ),
                              style: AppTypography.body(palette.fg).copyWith(height: 1.4, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppLocaleNotifier.pick(
                          'HRV ночи ${_telemetry.hrv > 0 ? _telemetry.hrv.toStringAsFixed(0) : '64'} · ваша норма ${_baseline.meanHrv.toStringAsFixed(0)}',
                          'Түнкү HRV ${_telemetry.hrv > 0 ? _telemetry.hrv.toStringAsFixed(0) : '64'} · норма ${_baseline.meanHrv.toStringAsFixed(0)}',
                          'Night HRV ${_telemetry.hrv > 0 ? _telemetry.hrv.toStringAsFixed(0) : '64'} · your baseline ${_baseline.meanHrv.toStringAsFixed(0)}',
                        ),
                        style: AppTypography.bodySemibold(palette.fg),
                      ),
                      if (_miss != null) ...[
                        const SizedBox(height: 6),
                        Text(_miss!, style: AppTypography.caption(palette.secondary)),
                      ],
                      if (_climate != ClimateMode.normal) ...[
                        const SizedBox(height: 6),
                        Text(
                          _climate == ClimateMode.altitude
                              ? AppLocaleNotifier.pick('Режим высокогорья: цель нагрузки снижена.', 'Бийик тоо режими.', 'Altitude mode: strain budget cut.')
                              : AppLocaleNotifier.pick('Режим жары: цель нагрузки снижена.', 'Ысык режим.', 'Heat mode: strain budget cut.'),
                          style: AppTypography.caption(AppColors.amber),
                        ),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DayJournalScreen()),
                          ),
                          child: Text(AppLocaleNotifier.pick('Записать день', 'Күндү жазуу', 'Log the day')),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await widget.bleBridge.triggerHeartRateMeasurement();
                          },
                          icon: const Icon(Icons.favorite_outline, size: 16),
                          label: Text(AppLocaleNotifier.pick('Замерить пульс', 'Пульсту өлчөө', 'Measure heart rate')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_calDays < 14)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: CircaCalibrationCard(
                    currentDay: _calDays,
                    totalDays: 14,
                  ),
                ),
              ),

            if (_userProfile.gender == Gender.female)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: GlassCard(
                    onTap: widget.onOpenAvatar,
                    child: Row(
                      children: [
                        MascotFace(
                          state: AvatarManager.calculateState(_telemetry, baseline: _baseline),
                          size: 72,
                          climate: _climate,
                          onTap: widget.onOpenAvatar,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppLocaleNotifier.pick('Барыс', 'Барыс', 'Barys'), style: AppTypography.bodySemibold(palette.fg)),
                              const SizedBox(height: 4),
                              Text(
                                DayCopy.morning(
                                  sleepScore: sleepScore,
                                  tMin: strainResult.targetStrainMin,
                                  tMax: strainResult.targetStrainMax,
                                  miss: _miss,
                                  climate: _climate,
                                ),
                                style: AppTypography.caption(palette.secondary).copyWith(height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_userProfile.gender != Gender.female && _partner != null && _partner!.isLinked)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: CircaPartnerCycleCard(
                    data: _partner!,
                    onTap: () => CircaPartnerCycleSheet.show(context, _partner!),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _stat(palette, AppLocaleNotifier.pick('ЧСС', 'ЖС', 'HR'),
                          '${_telemetry.heartRate > 0 ? _telemetry.heartRate : 72}', 'bpm'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat(palette, 'HRV',
                          _telemetry.hrv > 0 ? _telemetry.hrv.toStringAsFixed(0) : '64', 'мс'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat(palette, AppLocaleNotifier.pick('Покой', 'Тынч', 'Resting'),
                          '${_telemetry.restingHeartRate > 0 ? _telemetry.restingHeartRate : 52}', 'bpm'),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Row(
                  children: [
                    Expanded(
                      child: _link(
                        palette,
                        AppLocaleNotifier.pick('Дневник', 'Күндөлүк', 'Journal'),
                        Icons.edit_note,
                        () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DayJournalScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _link(
                        palette,
                        AppLocaleNotifier.pick('Друзья', 'Достор', 'Friends'),
                        Icons.people_outline,
                        () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => PrivateLeagueScreen(bleBridge: widget.bleBridge)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _link(
                        palette,
                        AppLocaleNotifier.pick('Барыс', 'Барыс', 'Barys'),
                        Icons.pets_outlined,
                        widget.onOpenAvatar,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _link(
                        palette,
                        AppLocaleNotifier.pick('Часы', 'Саат', 'Watch'),
                        Icons.watch_outlined,
                        () => widget.onOpenDeviceSettings?.call(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(KalkanColors palette, String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption(palette.secondary)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: AppTypography.metricValue(palette.fg)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(unit, style: AppTypography.caption(palette.muted)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _link(KalkanColors palette, String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: () {
        CircaHaptics.selectionClick();
        onTap();
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.fg,
        backgroundColor: palette.surface,
        side: BorderSide(color: palette.hairline),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: palette.secondary),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.caption(palette.fg)),
        ],
      ),
    );
  }
}
