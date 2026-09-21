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
  UserProfile _userProfile = const UserProfile();
  StreamSubscription<BleTelemetry>? _sub;

  @override
  void initState() {
    super.initState();
    _telemetry = widget.bleBridge.currentTelemetry;
    _loadProfile();
    _syncIosWidgets();
    UserProfileRepository.profileNotifier.addListener(_onProfileNotifier);
    _sub = widget.bleBridge.telemetryStream.listen((data) {
      if (!mounted) return;
      setState(() => _telemetry = data);
      _syncIosWidgets();
    });
  }

  void _onProfileNotifier() {
    if (mounted) {
      setState(() => _userProfile = UserProfileRepository.profileNotifier.value);
    }
  }

  void _syncIosWidgets() {
    final readiness = ReadinessEngine.calculate(_telemetry, baseline: _baseline);
    IosWidgetService.updateWidgets(
      telemetry: _telemetry,
      readiness: readiness,
      currentStrain: _telemetry.currentDayStrain > 0 ? _telemetry.currentDayStrain : 12.4,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    UserProfileRepository.profileNotifier.removeListener(_onProfileNotifier);
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await UserProfileRepository.loadProfile();
      if (mounted) setState(() => _userProfile = p);
    } catch (_) {}
  }

  String _coach(int score, double strainMax, AppLanguage lang) {
    final ru = lang != AppLanguage.kyrgyz;
    if (score >= 67) {
      return ru
          ? 'Тело готово к нагрузке. Можно тяжёлую сессию, потолок strain ${strainMax.toStringAsFixed(1)}.'
          : 'Денең жүктөмгө даяр. Оор машыгуу мүмкүн, strain чеги ${strainMax.toStringAsFixed(1)}.';
    }
    if (score >= 34) {
      return ru
          ? 'Обычный день. Держи среднюю нагрузку, не заходи за ${strainMax.toStringAsFixed(1)}.'
          : 'Кадимки күн. Орто жүктөмдү кармоо, ${strainMax.toStringAsFixed(1)}дан ашпа.';
    }
    return ru
        ? 'Восстановление слабое. Сегодня зона 1–2, сон раньше обычного.'
        : 'Калыбына келүү начар. Бүгүн 1–2 зона, уйкуну эртерээк.';
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final language = AppLocaleNotifier.current;
    final readiness = ReadinessEngine.calculate(_telemetry, baseline: _baseline);

    final rawStrain = _telemetry.currentDayStrain > 0
        ? _telemetry.currentDayStrain
        : StrainEngine.calculateStrainFromZones(_telemetry.zoneMinutes);
    final currentStrain = rawStrain > 0 ? rawStrain : 12.4;
    final strainResult = StrainEngine.evaluate(
      currentStrain: currentStrain,
      recoveryZone: readiness.zone,
      zoneMinutes: _telemetry.zoneMinutes,
    );
    final sleepResult = SleepEngine.calculate(telemetry: _telemetry, baseline: _baseline);
    final sleepScore = sleepResult.sleepPerformanceScore > 0 ? sleepResult.sleepPerformanceScore : 88;
    final name = _userProfile.name.isNotEmpty ? _userProfile.name : AppStrings.tr('home_guest', language);
    final isConnected = _telemetry.isConnected;
    final ru = language != AppLanguage.kyrgyz;

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
                  child: Text(
                    _coach(readiness.score, strainResult.targetStrainMax, language),
                    style: AppTypography.body(palette.fg).copyWith(height: 1.4),
                  ),
                ),
              ),
            ),
            if (_baseline.isCalibrating)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: CircaCalibrationCard(
                    currentDay: _baseline.calibrationDaysDone,
                    totalDays: 14,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _stat(palette, ru ? 'ЧСС' : 'ЖС',
                          '${_telemetry.heartRate > 0 ? _telemetry.heartRate : 72}', 'bpm'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat(palette, 'HRV',
                          _telemetry.hrv > 0 ? _telemetry.hrv.toStringAsFixed(0) : '64', 'мс'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat(palette, ru ? 'Покой' : 'Тынч',
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
                        ru ? 'Друзья' : 'Достор',
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
                        ru ? 'Персонаж' : 'Каарман',
                        Icons.pets_outlined,
                        widget.onOpenAvatar,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _link(
                        palette,
                        ru ? 'Часы' : 'Саат',
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
