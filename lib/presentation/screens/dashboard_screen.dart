import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
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
import '../widgets/circa_photo_of_day_dialog.dart';
import '../widgets/circa_recovery_breakdown_sheet.dart';
import '../widgets/precision_card.dart';
import '../widgets/precision_coach_card.dart';
import '../widgets/precision_pulse_wave.dart';
import '../widgets/precision_recovery_ring.dart';
import '../widgets/precision_sleep_card.dart';
import '../widgets/precision_strain_bar.dart';
import 'private_league_screen.dart';

/// Precision Biometric Recovery Tracker Home Screen (Whoop 5.0 / Oura Athletic)
/// - Dark obsidian background (#08090C, strictly in #050506–#12141A range)
/// - Flat surface cards with 1px hairline border (#1C2029)
/// - STRICTLY NO shadows, NO blur, NO glassmorphism, NO glow effects, NO radial gradients
/// - Three distinct type roles, only regular (w400) and semibold (w600) weights
/// - Exactly three accents: sage (#52B788), amber (#DE8A36), rose (#D14949)
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

  @override
  void initState() {
    super.initState();
    _telemetry = widget.bleBridge.currentTelemetry;
    _loadProfile();
    _syncIosWidgets();

    UserProfileRepository.profileNotifier.addListener(_onProfileNotifier);

    widget.bleBridge.telemetryStream.listen((data) {
      if (mounted) {
        setState(() {
          _telemetry = data;
        });
        _syncIosWidgets();
      }
    });
  }

  void _onProfileNotifier() {
    if (mounted) {
      setState(() {
        _userProfile = UserProfileRepository.profileNotifier.value;
      });
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
    UserProfileRepository.profileNotifier.removeListener(_onProfileNotifier);
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await UserProfileRepository.loadProfile();
      if (mounted) {
        setState(() {
          _userProfile = p;
        });
      }
    } catch (_) {}
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return '$weekday, ${now.day} $month';
  }

  @override
  Widget build(BuildContext context) {
    // 1. Calculate biometric intelligence
    final readiness = ReadinessEngine.calculate(
      _telemetry,
      baseline: _baseline,
    );

    final rawStrain = _telemetry.currentDayStrain > 0
        ? _telemetry.currentDayStrain
        : StrainEngine.calculateStrainFromZones(_telemetry.zoneMinutes);

    final currentStrain = rawStrain > 0 ? rawStrain : 12.4;

    final strainResult = StrainEngine.evaluate(
      currentStrain: currentStrain,
      recoveryZone: readiness.zone,
      zoneMinutes: _telemetry.zoneMinutes,
    );

    final sleepResult = SleepEngine.calculate(
      telemetry: _telemetry,
      baseline: _baseline,
    );

    final athleteName = _userProfile.name.isNotEmpty
        ? _userProfile.name.toUpperCase()
        : 'ATHLETE';

    final isConnected = _telemetry.isConnected;

    // Sleep stages calculation
    final totalSleepMins = _telemetry.sleepMinutes > 0 ? _telemetry.sleepMinutes : 468;
    final deepMins = _telemetry.deepSleepMinutes > 0 ? _telemetry.deepSleepMinutes : 102;
    final remMins = _telemetry.remSleepMinutes > 0 ? _telemetry.remSleepMinutes : 116;
    final lightMins = (totalSleepMins - deepMins - remMins).clamp(60, 360);
    final awakeMins = (_telemetry.timeInBedMinutes - totalSleepMins).clamp(10, 90);

    return Scaffold(
      backgroundColor: AppColors.obsidian, // Flat dark obsidian #08090C
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // =================================================================
            // 1. TOP HEADER: Athlete ID, Date & BLE Status (Monospace & Swiss Grid)
            // =================================================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Athlete Avatar + Name & Date
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            CircaHaptics.selectionClick();
                            CircaAvatarPickerDialog.show(context, _userProfile);
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.hairline, width: 1.0),
                                ),
                                child: ClipOval(
                                  child: AvatarImageProvider.buildAvatarWidget(path: _userProfile.avatarPath),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.hairline, width: 1.0),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 8.5, color: AppColors.amber),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              athleteName,
                              style: AppTypography.monoLabel.copyWith(
                                fontSize: 13,
                                letterSpacing: 1.8,
                                color: AppColors.textNearWhite,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCurrentDate(),
                              style: AppTypography.monoUnit.copyWith(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // BLE Sync Status Pill
                    GestureDetector(
                      onTap: () {
                        CircaHaptics.selectionClick();
                        widget.onOpenDeviceSettings?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.hairline, width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
                              isConnected ? 'SYNCED' : 'OFFLINE',
                              style: AppTypography.monoBadge.copyWith(
                                color: isConnected ? AppColors.sage : AppColors.rose,
                                fontSize: 9.5,
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

            // =================================================================
            // 2. HERO: Circular Recovery Ring (Score out of 100, 0 glow, 3 metrics)
            // =================================================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: PrecisionCard(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 18),
                  child: PrecisionRecoveryRing(
                    score: readiness.score,
                    zone: readiness.zone,
                    hrv: _telemetry.hrv,
                    restingHeartRate: _telemetry.restingHeartRate,
                    skinTempDeviation: _telemetry.skinTempDeviation,
                    size: 200,
                    onTap: () {
                      CircaHaptics.selectionClick();
                      CircaRecoveryBreakdownSheet.show(
                        context,
                        readiness,
                        telemetry: _telemetry,
                        baseline: _baseline,
                        userName: athleteName,
                      );
                    },
                  ),
                ),
              ),
            ),

            // =================================================================
            // 3. DAILY STRAIN BAR with Numeric Target Range
            // =================================================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: PrecisionStrainBar(
                  currentStrain: currentStrain,
                  targetMin: strainResult.targetStrainMin,
                  targetMax: strainResult.targetStrainMax,
                  activeCalories: _telemetry.calories,
                  activeMinutes: 52,
                ),
              ),
            ),

            // =================================================================
            // 4. LIVE HEART RATE CARD with Simple Line Waveform (No glow)
            // =================================================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: PrecisionPulseWave(
                  bpm: _telemetry.heartRate > 0 ? _telemetry.heartRate : 72,
                  restingBpm: _telemetry.restingHeartRate > 0 ? _telemetry.restingHeartRate : 52,
                  peakBpm: 154,
                ),
              ),
            ),

            // =================================================================
            // 5. SLEEP SUMMARY CARD (4-Stage Breakdown Grid)
            // =================================================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: PrecisionSleepCard(
                  totalMinutes: totalSleepMins,
                  deepMinutes: deepMins,
                  remMinutes: remMins,
                  lightMinutes: lightMins,
                  awakeMinutes: awakeMins,
                  sleepPerformanceScore: sleepResult.sleepPerformanceScore > 0
                      ? sleepResult.sleepPerformanceScore
                      : 88,
                ),
              ),
            ),

            // =================================================================
            // 6. ATHLETIC COACHING INSIGHT (Swiss Precision Plain Grotesk)
            // =================================================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: PrecisionCoachCard(
                  title: 'PHYSIOLOGICAL READOUT',
                  actionLabel: readiness.score >= 66
                      ? 'PRIMED FOR LOAD'
                      : (readiness.score >= 33 ? 'MAINTENANCE LOAD' : 'ACTIVE RECOVERY'),
                  accentColor: readiness.score >= 66
                      ? AppColors.sage
                      : (readiness.score >= 33 ? AppColors.amber : AppColors.rose),
                  insight: readiness.score >= 66
                      ? 'Autonomic recovery is optimal. Parasympathetic dominance detected (+14% HRV vs baseline). Cardiovascular and neuromuscular systems are primed to absorb maximum strain today.'
                      : (readiness.score >= 33
                          ? 'Baseline recovery verified. Physiological markers are stable. Recommended strain ceiling capped at ${strainResult.targetStrainMax.toStringAsFixed(1)} to prevent autonomic fatigue.'
                          : 'Cardiac output indicates elevated autonomic stress. Suppress high-glycolytic sessions. Prioritize parasympathetic breathing and restorative zone 1 mobility.'),
                ),
              ),
            ),

            // =================================================================
            // 7. PRECISION DUAL ACTION BAR (1px Hairline Buttons)
            // =================================================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  children: [
                    // Ряд 1: Фото Дня + Круг Друзей
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              CircaHaptics.selectionClick();
                              CircaPhotoOfDayDialog.show(
                                context,
                                telemetry: _telemetry,
                                readiness: readiness,
                                currentStrain: currentStrain,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textNearWhite,
                              backgroundColor: AppColors.surface,
                              side: const BorderSide(color: AppColors.hairline, width: 1.0),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.camera_alt_outlined, size: 14, color: AppColors.amber),
                                const SizedBox(width: 8),
                                Text(
                                  'ФОТО ДНЯ',
                                  style: AppTypography.monoLabel.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textNearWhite,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              CircaHaptics.selectionClick();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PrivateLeagueScreen(bleBridge: widget.bleBridge),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textNearWhite,
                              backgroundColor: AppColors.surface,
                              side: const BorderSide(color: AppColors.hairline, width: 1.0),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_outline, size: 14, color: AppColors.sage),
                                const SizedBox(width: 8),
                                Text(
                                  'КРУГ ДРУЗЕЙ',
                                  style: AppTypography.monoLabel.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textNearWhite,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Ряд 2: Био-Аватар + Настройки
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              CircaHaptics.selectionClick();
                              widget.onOpenAvatar();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textNearWhite,
                              backgroundColor: AppColors.surface,
                              side: const BorderSide(color: AppColors.hairline, width: 1.0),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: AppColors.sage,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'БИО-АВАТАР',
                                  style: AppTypography.monoLabel.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textNearWhite,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              CircaHaptics.selectionClick();
                              widget.onOpenDeviceSettings?.call();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textNearWhite,
                              backgroundColor: AppColors.surface,
                              side: const BorderSide(color: AppColors.hairline, width: 1.0),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.watch_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  'НАСТРОЙКИ',
                                  style: AppTypography.monoLabel.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textNearWhite,
                                  ),
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
          ],
        ),
      ),
    );
  }
}
