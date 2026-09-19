import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../domain/intelligence/sleep_engine.dart';
import '../../domain/models/telemetry.dart';
import 'glass_card.dart';

class CircaHypnogram extends StatelessWidget {
  final SleepAnalysisResult sleepResult;

  const CircaHypnogram({
    super.key,
    required this.sleepResult,
  });

  @override
  Widget build(BuildContext context) {
    final needHours = sleepResult.sleepNeedMinutes ~/ 60;
    final needMinutes = sleepResult.sleepNeedMinutes % 60;

    final actualHours = sleepResult.actualSleepMinutes ~/ 60;
    final actualMinutes = sleepResult.actualSleepMinutes % 60;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
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
                      color: AppColors.sage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ПОТРЕБНОСТЬ ВО СНЕ',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.raised,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Отбой: ${sleepResult.optimalBedtime}',
                  style: const TextStyle(
                    color: AppColors.fg,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Фактический сон vs Потребность
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$actualHoursч $actualMinutesм',
                style: const TextStyle(
                  color: AppColors.fg,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              Text(
                ' / Need: $needHoursч $needMinutesм',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sleepResult.sleepPerformanceScore >= 80
                      ? AppColors.sage.withValues(alpha: 0.16)
                      : AppColors.amber.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sleepResult.sleepPerformanceScore >= 80
                        ? AppColors.sage.withValues(alpha: 0.5)
                        : AppColors.amber.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '${sleepResult.sleepPerformanceScore}% ПОКРЫТИЯ',
                  style: TextStyle(
                    color: sleepResult.sleepPerformanceScore >= 80 ? AppColors.sage : AppColors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Декомпозиция Sleep Need: База + Долг + Надбавка за Strain
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.raised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNeedItem('База', '${sleepResult.baselineNeedMinutes ~/ 60}ч'),
                const Text('+', style: TextStyle(color: AppColors.faint, fontSize: 11)),
                _buildNeedItem('Долг 14д', '+${sleepResult.sleepDebtPortionMinutes}м'),
                const Text('+', style: TextStyle(color: AppColors.faint, fontSize: 11)),
                _buildNeedItem('За Strain', '+${sleepResult.strainSurchargeMinutes}м'),
                const Text('=', style: TextStyle(color: AppColors.faint, fontSize: 11)),
                _buildNeedItem('Итого Need', '$needHoursч $needMinutesм', isHighlight: true),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4 вклада Sleep Performance
          Row(
            children: [
              _buildFactorPill('Длительность', '${sleepResult.durationFactor}%'),
              const SizedBox(width: 6),
              _buildFactorPill('Эффективность', '${sleepResult.efficiencyFactor}%'),
              const SizedBox(width: 6),
              _buildFactorPill('Consistency', '${sleepResult.consistencyFactor}%'),
              const SizedBox(width: 6),
              _buildFactorPill('Релаксация', '${sleepResult.restorativeFactor}%'),
            ],
          ),
          const SizedBox(height: 14),

          // Векторная гипнограмма фаз сна
          const Text(
            'ГИПНОГРАММА ФАЗ СНА (СЕНСОР БРАСЛЕТА)',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),

          SizedBox(
            height: 64,
            child: CustomPaint(
              size: Size.infinite,
              painter: _HypnogramPainter(epochs: sleepResult.hypnogram),
            ),
          ),
          const SizedBox(height: 6),

          // Легенда фаз
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem('Глубокий', AppColors.sage),
              _buildLegendItem('REM (быстрый)', AppColors.amber),
              _buildLegendItem('Легкий', AppColors.muted),
              _buildLegendItem('Пробуждения', AppColors.rose),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNeedItem(String label, String val, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.faint, fontSize: 9)),
        Text(
          val,
          style: TextStyle(
            color: isHighlight ? AppColors.amber : AppColors.fg,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildFactorPill(String title, String val) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.raised,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(val, style: const TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 1),
            Text(title, style: const TextStyle(color: AppColors.faint, fontSize: 8)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 9)),
      ],
    );
  }
}

class _HypnogramPainter extends CustomPainter {
  final List<SleepEpoch> epochs;

  _HypnogramPainter({required this.epochs});

  @override
  void paint(Canvas canvas, Size size) {
    if (epochs.isEmpty) return;

    final totalDuration = epochs.fold<int>(0, (sum, e) => sum + e.durationMinutes);
    if (totalDuration <= 0) return;

    // Уровни по Y: Awake (верх), REM, Light, Deep (низ)
    double getY(SleepStageType stage) {
      switch (stage) {
        case SleepStageType.awake:
          return size.height * 0.12;
        case SleepStageType.rem:
          return size.height * 0.38;
        case SleepStageType.light:
          return size.height * 0.65;
        case SleepStageType.deep:
          return size.height * 0.90;
      }
    }

    Color getColor(SleepStageType stage) {
      switch (stage) {
        case SleepStageType.awake:
          return AppColors.rose;
        case SleepStageType.rem:
          return AppColors.amber;
        case SleepStageType.light:
          return AppColors.muted;
        case SleepStageType.deep:
          return AppColors.sage;
      }
    }

    var currentMinutes = 0;
    final path = Path();

    for (var i = 0; i < epochs.length; i++) {
      final ep = epochs[i];
      final startX = (currentMinutes / totalDuration) * size.width;
      final endX = ((currentMinutes + ep.durationMinutes) / totalDuration) * size.width;
      final y = getY(ep.stage);

      if (i == 0) {
        path.moveTo(startX, y);
      } else {
        path.lineTo(startX, y);
      }
      path.lineTo(endX, y);

      // Заливка сегмента фазы
      final rect = Rect.fromLTRB(startX, y, endX, size.height);
      final fillPaint = Paint()..color = getColor(ep.stage).withValues(alpha: 0.18);
      canvas.drawRect(rect, fillPaint);

      currentMinutes += ep.durationMinutes;
    }

    // Отрисовка ступенчатой линии гипнограммы
    final linePaint = Paint()
      ..color = AppColors.fg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _HypnogramPainter oldDelegate) => true;
}
