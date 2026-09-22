import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../domain/intelligence/healthspan_engine.dart';
import '../../domain/intelligence/sleep_engine.dart';
import '../../domain/intelligence/stress_engine.dart';
import '../../domain/models/personal_baseline.dart';
import '../../data/history/biometrics_history_repository.dart';
import '../../data/storage/day_snapshot_repository.dart';
import '../../data/storage/demo_mode_store.dart';
import '../widgets/circa_healthspan_card.dart';
import '../widgets/circa_hypnogram.dart';
import '../widgets/circa_sparkline.dart';
import '../widgets/circa_stress_timeline.dart';
import '../widgets/glass_card.dart';
import '../widgets/metric_dial.dart';
import '../widgets/weekly_metric_chart.dart';
import '../../domain/intelligence/readiness_engine.dart';
import '../../domain/intelligence/strain_engine.dart';

class AnalyticsScreen extends StatefulWidget {
  final UteBleBridge bleBridge;

  const AnalyticsScreen({super.key, required this.bleBridge});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedPeriod = 1; // 0: 24ч, 1: 7д, 2: 30д, 3: 6мес
  final _baseline = const PersonalBaseline();
  List<DaySnapshot> _week = const [];

  @override
  void initState() {
    super.initState();
    _loadWeek();
  }

  Future<void> _loadWeek() async {
    await DaySnapshotRepository.seedPreviewIfEmpty(widget.bleBridge.currentTelemetry);
    final rec = ReadinessEngine.calculate(widget.bleBridge.currentTelemetry, baseline: _baseline);
    await DaySnapshotRepository.recordTelemetry(
      widget.bleBridge.currentTelemetry,
      recovery: rec.score,
      sleep: SleepEngine.calculate(telemetry: widget.bleBridge.currentTelemetry, baseline: _baseline).sleepPerformanceScore,
    );
    final week = await DaySnapshotRepository.lastDays(7);
    if (mounted) setState(() => _week = week);
  }

  List<HistoricalPoint> _pts(double Function(DaySnapshot s) pick) {
    if (_week.isEmpty) return const [];
    return [
      for (final s in _week)
        HistoricalPoint(
          timestamp: DateTime.tryParse(s.dateKey) ?? DateTime.now(),
          value: pick(s),
          label: s.dateKey.substring(5).replaceAll('-', '.'),
        )
    ];
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.bleBridge.currentTelemetry;
    final sleepAnalysis = SleepEngine.calculate(
      telemetry: telemetry,
      baseline: _baseline,
    );
    final stressSummary = StressEngine.analyze(
      currentScore: telemetry.currentStressScore,
      heartRate: telemetry.heartRate,
      restingHeartRate: telemetry.restingHeartRate,
      hrv: telemetry.hrv,
      meanHrv: _baseline.meanHrv,
      sleepMinutes: telemetry.sleepMinutes,
      dayStrain: telemetry.currentDayStrain,
    );
    final healthspan = HealthspanEngine.calculate(
      restingHeartRate: telemetry.restingHeartRate,
      weeklyZone2Minutes: 160,
      weeklyZone5Minutes: 24,
      sleepConsistency: telemetry.sleepConsistency,
    );

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        final palette = KalkanColors.of(context);
        return Scaffold(
          backgroundColor: palette.bg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              AppStrings.tr('analytics_title', language),
              style: TextStyle(
                color: palette.fg,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                MetricDial(
                  label: AppStrings.tr('home_sleep', language),
                  value: '${sleepAnalysis.sleepPerformanceScore}%',
                  progress: (sleepAnalysis.sleepPerformanceScore) / 100,
                  color: AppColors.sleepBlue,
                  size: 88,
                ),
                MetricDial(
                  label: AppStrings.tr('home_recovery', language),
                  value: '${ReadinessEngine.calculate(telemetry, baseline: _baseline).score}%',
                  progress: ReadinessEngine.calculate(telemetry, baseline: _baseline).score / 100,
                  color: ReadinessEngine.calculate(telemetry, baseline: _baseline).zone.color,
                  size: 88,
                ),
                MetricDial(
                  label: AppStrings.tr('home_strain', language),
                  value: (telemetry.currentDayStrain > 0 ? telemetry.currentDayStrain : 0).toStringAsFixed(1),
                  progress: ((telemetry.currentDayStrain > 0 ? telemetry.currentDayStrain : 0) / 21).clamp(0.0, 1.0),
                  color: AppColors.strainBlue,
                  size: 88,
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Переключатель временных интервалов
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: palette.raised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.hairline),
              ),
              child: Row(
                children: [
                  _buildPeriodTab(0, AppLocaleNotifier.pick('24ч', '24с', '24h')),
                  _buildPeriodTab(1, AppLocaleNotifier.pick('7 дней', '7 күн', '7 days')),
                  _buildPeriodTab(2, AppLocaleNotifier.pick('30 дней', '30 күн', '30 days')),
                  _buildPeriodTab(3, AppLocaleNotifier.pick('6 мес', '6 ай', '6 mo')),
                ],
              ),
            ),
            SizedBox(height: 16),
            GlassCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocaleNotifier.pick('Пульс', 'Пульс', 'Heart rate'), style: TextStyle(color: palette.secondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(telemetry.heartRate > 0 ? '${telemetry.heartRate}' : '—', style: TextStyle(color: palette.fg, fontSize: 32, fontWeight: FontWeight.w600)),
                        Text('bpm', style: TextStyle(color: palette.secondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocaleNotifier.pick('Покой', 'Тынч', 'Resting'), style: TextStyle(color: palette.secondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(telemetry.restingHeartRate > 0 ? '${telemetry.restingHeartRate}' : '—', style: TextStyle(color: palette.fg, fontSize: 32, fontWeight: FontWeight.w600)),
                        Text('bpm', style: TextStyle(color: palette.secondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            WeeklyMetricChart(
              title: AppLocaleNotifier.pick('Сон, 7 дней', 'Уйку, 7 күн', 'Sleep, 7 days'),
              unit: '%',
              points: _pts((s) => s.sleep.toDouble()).isNotEmpty ? _pts((s) => s.sleep.toDouble()) : (DemoModeStore.enabled.value ? BiometricsHistoryRepository.getSleepHistory(_currentHistoryPeriod) : const []),
              color: AppColors.sleepBlue,
              maxValue: 100,
            ),
            const SizedBox(height: 12),
            WeeklyMetricChart(
              title: AppLocaleNotifier.pick('Восстановление, 7 дней', 'Калыбына келүү, 7 күн', 'Recovery, 7 days'),
              unit: '%',
              points: _pts((s) => s.recovery.toDouble()).isNotEmpty ? _pts((s) => s.recovery.toDouble()) : (DemoModeStore.enabled.value ? BiometricsHistoryRepository.getRecoveryHistory(_currentHistoryPeriod) : const []),
              color: AppColors.sage,
              maxValue: 100,
            ),
            const SizedBox(height: 12),
            WeeklyMetricChart(
              title: AppLocaleNotifier.pick('Нагрузка, 7 дней', 'Жүктөм, 7 күн', 'Strain, 7 days'),
              unit: '',
              points: _pts((s) => s.strain).isNotEmpty ? _pts((s) => s.strain) : (DemoModeStore.enabled.value ? BiometricsHistoryRepository.getStrainHistory(_currentHistoryPeriod) : const []),
              color: AppColors.strainBlue,
              maxValue: 21,
            ),
            const SizedBox(height: 16),
            // 1. Профиль пульса (ЧСС) по периодам
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getHeartRateCardTitle(_selectedPeriod),
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                      Text(
                        '${AppLocaleNotifier.pick('Покой', 'Тынч', 'Resting')}: ${telemetry.restingHeartRate} bpm',
                        style: TextStyle(color: AppColors.sage, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: CircaSparkline(
                      points: BiometricsHistoryRepository.getHeartRateHistory(_currentHistoryPeriod),
                      lineColor: AppColors.rose,
                      height: 90,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildAxisLabels(_selectedPeriod),
                ],
              ),
            ),
            SizedBox(height: 14),

            // 2. Архитектура сна и гипнограмма
            CircaHypnogram(sleepResult: sleepAnalysis),
            SizedBox(height: 14),

            // 3. Дневной монитор стресса (лента дня)
            CircaStressTimeline(stressSummary: stressSummary),
            SizedBox(height: 14),

            // 4. Биологический возраст CIRCA (Healthspan)
            CircaHealthspanCard(healthspan: healthspan),
            SizedBox(height: 14),

            // 5. Гормональный цикл и адаптация нагрузки
            GlassCard(
              onTap: () => _showCycleDetailsModal(context),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_graph, color: AppColors.amber, size: 20),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocaleNotifier.pick('Цикл', 'Цикл', 'Cycle'),
                          style: TextStyle(
                            color: AppColors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          AppLocaleNotifier.pick(
                            'Фолликулярная фаза · ВСР на пике',
                            'Фолликулярдык фаза · ЖЖВ туу чокусунда',
                            'Follicular phase · HRV peak',
                          ),
                          style: TextStyle(
                            color: AppColors.fg,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          AppLocaleNotifier.pick(
                            'Нажмите для подсказки по нагрузкам ›',
                            'Жүктөм боюнча сунуштарды көрүү ›',
                            'Tap for strain guidance ›',
                          ),
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: AppColors.muted, size: 12),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
      },
    );
  }

  void _showCycleDetailsModal(BuildContext context) {
    CircaHaptics.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.auto_graph, color: AppColors.amber, size: 20),
                SizedBox(width: 8),
                Text(
                  AppLocaleNotifier.pick(
                    'ФИЗИОЛОГИЧЕСКИЙ ЦИКЛ И ВАРИАТИВНОСТЬ',
                    'ФИЗИОЛОГИЯЛЫК ЦИКЛ ЖАНА ВАРИАТИВДҮҮЛҮК',
                    'PHYSIOLOGICAL CYCLE & VARIABILITY',
                  ),
                  style: TextStyle(color: AppColors.amber, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: -0.1),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.raised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                AppLocaleNotifier.pick(
                  'Колебания ВСР и пульса покоя в лютеиновой или фолликулярной фазе — это естественный физиологический процесс, а не падение спортивной формы.',
                  'Лютеиндик же фолликулярдык фазадагы ЖЖВ менен пульстун өзгөрүшү — бул табигый физиологиялык процесс, спорттук форманын түшүшү эмес.',
                  'Fluctuations in HRV and resting HR across cycle phases are natural physiological adaptations, not a loss of fitness.',
                ),
                style: TextStyle(color: AppColors.fg, fontSize: 13, height: 1.4),
              ),
            ),
            SizedBox(height: 12),
            Text(
              AppLocaleNotifier.pick(
                'СААТ-1 автоматически учитывает фазу цикла и калибрует целевой бюджет суточной нагрузки, защищая нервную систему и сердце от перетренированности.',
                'СААТ-1 цикл фазасын автоматтык түрдө эске алып, суткалык жүктөм бюджетин калибрлеп, нерв системасын ашыкча чарчоодон коргойт.',
                'SAAT-1 automatically factors in your cycle phase and calibrates your daily strain budget, guarding against overtraining.',
              ),
              style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
            ),
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocaleNotifier.pick(
                        'Текущая фаза: Фолликулярная (Эстроген ↑, ВСР на пике, оптимум для тренировок)',
                        'Учурдагы фаза: Фолликулярдык (Эстроген ↑, ЖЖВ туу чокусунда, машыгууларга оптималдуу)',
                        'Current phase: Follicular (Estrogen ↑, peak HRV, optimal for high strain)',
                      ),
                      style: TextStyle(color: AppColors.amber, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  HistoryPeriod get _currentHistoryPeriod {
    switch (_selectedPeriod) {
      case 0:
        return HistoryPeriod.day24h;
      case 1:
        return HistoryPeriod.week7d;
      case 2:
        return HistoryPeriod.month30d;
      case 3:
        return HistoryPeriod.months6;
      default:
        return HistoryPeriod.week7d;
    }
  }

  String _getHeartRateCardTitle(int period) {
    switch (period) {
      case 0:
        return AppLocaleNotifier.pick('СУТОЧНЫЙ ПРОФИЛЬ ПУЛЬСА (24 ЧАСА)', 'КҮНДҮК ПУЛЬС ПРОФИЛИ (24 СААТ)', 'DAILY HEART RATE PROFILE (24 HOURS)');
      case 1:
        return AppLocaleNotifier.pick('НЕДЕЛЬНЫЙ ТРЕНД ПУЛЬСА (7 ДНЕЙ)', 'ЖУМАЛЫК ПУЛЬС ТРЕНДИ (7 КҮН)', 'WEEKLY HEART RATE TREND (7 DAYS)');
      case 2:
        return AppLocaleNotifier.pick('МЕСЯЧНЫЙ ТРЕНД ПУЛЬСА (30 ДНЕЙ)', 'АЙЛЫК ПУЛЬС ТРЕНДИ (30 КҮН)', 'MONTHLY HEART RATE TREND (30 DAYS)');
      case 3:
        return AppLocaleNotifier.pick('ПОЛУГОДОВОЙ ТРЕНД ПУЛЬСА (6 МЕСЯЦЕВ)', 'ЖАРЫМ ЖЫЛДЫК ПУЛЬС ТРЕНДИ (6 АЙ)', '6-MONTH HEART RATE TREND');
      default:
        return AppLocaleNotifier.pick('ТРЕНД ПУЛЬСА (ЧСС)', 'ПУЛЬС ТРЕНДИ (ЖЖК)', 'HEART RATE TREND (HR)');
    }
  }

  Widget _buildAxisLabels(int period) {
    switch (period) {
      case 0:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('00:00', style: TextStyle(color: AppColors.faint, fontSize: 10)),
            Text('06:00', style: TextStyle(color: AppColors.faint, fontSize: 10)),
            Text('12:00 (${AppLocaleNotifier.pick('Пик', 'Чок', 'Peak')})', style: TextStyle(color: AppColors.rose, fontSize: 10, fontWeight: FontWeight.w600)),
            Text('18:00', style: TextStyle(color: AppColors.faint, fontSize: 10)),
            Text('23:59', style: TextStyle(color: AppColors.faint, fontSize: 10)),
          ],
        );
      case 1:
        final labels = AppLocaleNotifier.pick(
          ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
          ['Дш', 'Шш', 'Шр', 'Бш', 'Жм', 'Иш', 'Жк'],
          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        );
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 0; i < 6; i++)
              Text(labels[i], style: TextStyle(color: AppColors.faint, fontSize: 10)),
            Text(labels[6], style: TextStyle(color: AppColors.rose, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        );
      case 2:
        final w1 = AppLocaleNotifier.pick('1-я нед', '1-апта', 'Wk 1');
        final w2 = AppLocaleNotifier.pick('2-я нед', '2-апта', 'Wk 2');
        final w3 = AppLocaleNotifier.pick('3-я нед', '3-апта', 'Wk 3');
        final w4 = AppLocaleNotifier.pick('4-я нед', '4-апта', 'Wk 4');
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(w1, style: TextStyle(color: AppColors.faint, fontSize: 10)),
            Text(w2, style: TextStyle(color: AppColors.faint, fontSize: 10)),
            Text(w3, style: TextStyle(color: AppColors.faint, fontSize: 10)),
            Text(w4, style: TextStyle(color: AppColors.rose, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        );
      case 3:
        final m6 = AppLocaleNotifier.pick('6 мес назад', '6 ай мурун', '6 mo ago');
        final m3 = AppLocaleNotifier.pick('3 мес назад', '3 ай мурун', '3 mo ago');
        final now = AppLocaleNotifier.pick('Текущий месяц', 'Учурдагы ай', 'Current month');
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(m6, style: TextStyle(color: AppColors.faint, fontSize: 10)),
            Text(m3, style: TextStyle(color: AppColors.faint, fontSize: 10)),
            Text(now, style: TextStyle(color: AppColors.rose, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPeriodTab(int index, String title) {
    final isSelected = _selectedPeriod == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          CircaHaptics.selectionClick();
          setState(() => _selectedPeriod = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? KalkanColors.of(context).surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? KalkanColors.of(context).fg : KalkanColors.of(context).secondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
