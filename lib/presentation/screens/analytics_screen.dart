import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/history/biometrics_history_repository.dart';
import '../../domain/intelligence/healthspan_engine.dart';
import '../../domain/intelligence/sleep_engine.dart';
import '../../domain/intelligence/stress_engine.dart';
import '../../domain/models/personal_baseline.dart';
import '../widgets/circa_healthspan_card.dart';
import '../widgets/circa_hypnogram.dart';
import '../widgets/circa_sparkline.dart';
import '../widgets/circa_stress_timeline.dart';
import '../widgets/glass_card.dart';

class AnalyticsScreen extends StatefulWidget {
  final UteBleBridge bleBridge;

  const AnalyticsScreen({super.key, required this.bleBridge});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedPeriod = 1; // 0: 24ч, 1: 7д, 2: 30д, 3: 6мес
  final _baseline = const PersonalBaseline();

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.bleBridge.currentTelemetry;
    final sleepAnalysis = SleepEngine.calculate(
      telemetry: telemetry,
      baseline: _baseline,
    );
    final stressSummary = StressEngine.analyze(currentScore: telemetry.currentStressScore);
    final healthspan = HealthspanEngine.calculate(
      restingHeartRate: telemetry.restingHeartRate,
      weeklyZone2Minutes: 160,
      weeklyZone5Minutes: 24,
      sleepConsistency: telemetry.sleepConsistency,
    );

    final historyPeriod = switch (_selectedPeriod) {
      0 => HistoryPeriod.day24h,
      1 => HistoryPeriod.week7d,
      2 => HistoryPeriod.month30d,
      _ => HistoryPeriod.months6,
    };

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        return Scaffold(
          backgroundColor: AppColors.stage,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KALKAN BIOMETRICS',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                  ),
                ),
                Text(
                  AppStrings.tr('analytics_title', language),
                  style: const TextStyle(
                    color: AppColors.fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // Переключатель временных интервалов
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  _buildPeriodTab(0, '24ч'),
                  _buildPeriodTab(1, '7 дней'),
                  _buildPeriodTab(2, '30 дней'),
                  _buildPeriodTab(3, '6 мес'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. Суточный почасовой профиль пульса
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'СУТОЧНЫЙ ПРОФИЛЬ ПУЛЬСА (ЧСС)',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                      Text(
                        'Покой: ${telemetry.restingHeartRate} bpm',
                        style: const TextStyle(color: AppColors.sage, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: CircaSparkline(
                      points: BiometricsHistoryRepository.getHourlyHeartRate24h(),
                      lineColor: AppColors.rose,
                      height: 90,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('00:00', style: TextStyle(color: AppColors.faint, fontSize: 10)),
                      Text('06:00', style: TextStyle(color: AppColors.faint, fontSize: 10)),
                      Text('12:00 (Пик)', style: TextStyle(color: AppColors.rose, fontSize: 10, fontWeight: FontWeight.w700)),
                      Text('18:00', style: TextStyle(color: AppColors.faint, fontSize: 10)),
                      Text('23:59', style: TextStyle(color: AppColors.faint, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Архитектура сна и гипнограмма
            CircaHypnogram(sleepResult: sleepAnalysis),
            const SizedBox(height: 14),

            // 3. Тренды ВСР против 60-дневной базы
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ТРЕНД ВСР (rMSSD) И БАЗОВЫЙ КОРИДОР',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                      Text(
                        '${telemetry.hrv.toStringAsFixed(0)} мс',
                        style: const TextStyle(color: AppColors.sage, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Личный коридор нормы: ${_baseline.hrvNormalMin.toStringAsFixed(0)}–${_baseline.hrvNormalMax.toStringAsFixed(0)} мс',
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 60,
                    child: CircaSparkline(
                      points: BiometricsHistoryRepository.getHrvHistory(historyPeriod),
                      lineColor: AppColors.sage,
                      height: 60,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Дневной монитор стресса (лента дня)
            CircaStressTimeline(stressSummary: stressSummary),
            const SizedBox(height: 14),

            // 5. Биологический возраст CIRCA (Healthspan)
            CircaHealthspanCard(healthspan: healthspan),
            const SizedBox(height: 14),

            // 6. Гормональный цикл и физиологическая вариативность (Whoop 5.0)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.amber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'ФИЗИОЛОГИЧЕСКИЙ ЦИКЛ И ВАРИАТИВНОСТЬ',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Колебания ВСР и пульса покоя в лютеиновой или фолликулярной фазе — это естественный гормональный процесс, а не падение формы. Система автоматически калибрует целевой бюджет Strain.',
                    style: TextStyle(color: AppColors.fg, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.raised,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.amber, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Текущая фаза: Фолликулярная (Эстроген ↑, ВСР на пике)',
                            style: TextStyle(color: AppColors.amber, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. Дисклеймер о медицинских данных
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: AppColors.muted, size: 16),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'KALKAN СААТ-1 не ставит медицинских диагнозов. Данные температуры кожи, SpO2 и ВСР служат индикатором трендов восстановления ЦНС и тренировочной адаптации.',
                      style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildPeriodTab(int index, String title) {
    final isSelected = _selectedPeriod == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.raised : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.fg : AppColors.muted,
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
