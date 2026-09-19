import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/intelligence/readiness_engine.dart';
import '../../domain/intelligence/sleep_engine.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/telemetry.dart';
import '../widgets/circa_morning_briefing_dialog.dart';
import '../widgets/circa_readiness_ring.dart';
import '../widgets/circa_recovery_breakdown_sheet.dart';
import '../widgets/circa_share_sheet.dart';
import '../widgets/glass_card.dart';
import '../widgets/live_pulse_wave.dart';

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
    final barysQuote = AvatarManager.getRitualQuote(avatarProfile.state);
    final weekdayName = _getWeekdayName();

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
                            'Привет, $_userName · $weekdayName',
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

            // 2. Калибровочный баннер (если первые 14 дней)
            if (_baseline.isCalibrating)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tune, color: AppColors.amber, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Калибровка: день ${_baseline.calibrationDaysDone} из 14 · строим персональный профиль',
                            style: const TextStyle(
                              color: AppColors.fg,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        const SizedBox(height: 14),
                        // 3 ключевые метрики входа
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildMetricChip('ВСР', '${_telemetry.hrv.round()} мс'),
                            const SizedBox(width: 8),
                            Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.faint)),
                            const SizedBox(width: 8),
                            _buildMetricChip('Покой', '${_telemetry.restingHeartRate} bpm'),
                            const SizedBox(width: 8),
                            Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.faint)),
                            const SizedBox(width: 8),
                            _buildMetricChip('Кожа', '${_telemetry.skinTempDeviation >= 0 ? '+' : ''}${_telemetry.skinTempDeviation.toStringAsFixed(1)} °C'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Разбор 5 факторов',
                              style: TextStyle(
                                color: AppColors.faint,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 14, color: AppColors.faint),
                            const SizedBox(width: 14),
                            Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.faint)),
                            const SizedBox(width: 14),
                            GestureDetector(
                              onTap: () => CircaShareSheet.show(
                                context,
                                telemetry: _telemetry,
                                baseline: _baseline,
                                userName: _userName,
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.ios_share, size: 13, color: AppColors.muted),
                                  SizedBox(width: 4),
                                  Text(
                                    'Поделиться',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                    ],
                  ),
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
                          const Text(
                            'СОН И РИТУАЛ',
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

            // 6. Живой пульс в реальном времени с волной
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
                              const Text(
                                'ПУЛЬС В РЕАЛЬНОМ ВРЕМЕНИ',
                                style: TextStyle(
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
                                ' уд/мин',
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
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
}
