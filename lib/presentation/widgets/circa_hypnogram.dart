import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/circa_haptics.dart';
import '../../domain/intelligence/sleep_engine.dart';
import '../../domain/models/telemetry.dart';
import 'glass_card.dart';

/// Лаконичная карточка потребности во сне с возможностью раскрыть подробности в модальном окне
class CircaHypnogram extends StatelessWidget {
  final SleepAnalysisResult sleepResult;

  const CircaHypnogram({
    super.key,
    required this.sleepResult,
  });

  static void showSleepBreakdownSheet(BuildContext context, SleepAnalysisResult sleepResult) {
    CircaHypnogram(sleepResult: sleepResult)._showDetailsModal(context);
  }

  void _showDetailsModal(BuildContext context) {
    CircaHaptics.selectionClick();
    final needHours = sleepResult.sleepNeedMinutes ~/ 60;
    final needMinutes = sleepResult.sleepNeedMinutes % 60;
    final actualHours = sleepResult.actualSleepMinutes ~/ 60;
    final actualMinutes = sleepResult.actualSleepMinutes % 60;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.line, width: 1.5)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ручка шторки
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.faint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Заголовок модального окна с кнопкой закрытия
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'АРХИТЕКТУРА И ФАЗЫ СНА',
                          style: TextStyle(
                            color: AppColors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Фактический сон: $actualHoursч $actualMinutesм из $needHoursч $needMinutesм',
                          style: TextStyle(
                            color: AppColors.fg,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.muted, size: 22),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Декомпозиция Sleep Need: База + Долг + За Strain = Итого
                const Text(
                  'РАСЧЁТ ПОТРЕБНОСТИ ВО СНЕ (SLEEP NEED)',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNeedItem('База', '${sleepResult.baselineNeedMinutes ~/ 60}ч'),
                      Text('+', style: TextStyle(color: AppColors.faint, fontSize: 13)),
                      _buildNeedItem('Долг 14д', '+${sleepResult.sleepDebtPortionMinutes}м'),
                      Text('+', style: TextStyle(color: AppColors.faint, fontSize: 13)),
                      _buildNeedItem('За нагрузку', '+${sleepResult.strainSurchargeMinutes}м'),
                      Text('=', style: TextStyle(color: AppColors.faint, fontSize: 13)),
                      _buildNeedItem('Итого нужно', '$needHoursч $needMinutesм', isHighlight: true),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // 4 вклада Sleep Performance
                const Text(
                  'ФАКТОРЫ ВОССТАНОВЛЕНИЯ СНОМ',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    _buildFactorPill('Длительность', '${sleepResult.durationFactor}%'),
                    SizedBox(width: 8),
                    _buildFactorPill('Эффективность', '${sleepResult.efficiencyFactor}%'),
                    SizedBox(width: 8),
                    _buildFactorPill('Режим дня', '${sleepResult.consistencyFactor}%'),
                    SizedBox(width: 8),
                    _buildFactorPill('Релаксация', '${sleepResult.restorativeFactor}%'),
                  ],
                ),
                SizedBox(height: 20),

                // Векторная гипнограмма фаз сна
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ГИПНОГРАММА НОЧИ (ПО СЕНСОРУ)',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    Text(
                      'Отбой: ${sleepResult.optimalBedtime}',
                      style: const TextStyle(
                        color: AppColors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 80,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _HypnogramPainter(epochs: sleepResult.hypnogram),
                        ),
                      ),
                      SizedBox(height: 12),
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
                ),
                SizedBox(height: 20),

                // Кнопка закрытия
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.raised,
                      foregroundColor: AppColors.fg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.line),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'ЗАКРЫТЬ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needHours = sleepResult.sleepNeedMinutes ~/ 60;
    final needMinutes = sleepResult.sleepNeedMinutes % 60;
    final actualHours = sleepResult.actualSleepMinutes ~/ 60;
    final actualMinutes = sleepResult.actualSleepMinutes % 60;
    final coveragePercent = (sleepResult.sleepPerformanceScore).clamp(0, 100);

    return GlassCard(
      onTap: () => _showDetailsModal(context),
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
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.sage,
                    ),
                  ),
                  SizedBox(width: 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.raised,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bedtime_outlined, size: 12, color: AppColors.amber),
                    SizedBox(width: 4),
                    Text(
                      'Отбой: ${sleepResult.optimalBedtime}',
                      style: TextStyle(
                        color: AppColors.fg,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Фактический сон vs Потребность
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$actualHoursч $actualMinutesм',
                style: TextStyle(
                  color: AppColors.fg,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
              ),
              Text(
                ' / $needHoursч $needMinutesм',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: coveragePercent >= 80
                      ? AppColors.sage.withValues(alpha: 0.16)
                      : AppColors.amber.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: coveragePercent >= 80
                        ? AppColors.sage.withValues(alpha: 0.5)
                        : AppColors.amber.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '$coveragePercent% ПОКРЫТИЯ',
                  style: TextStyle(
                    color: coveragePercent >= 80 ? AppColors.sage : AppColors.amber,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          // Прогресс-бар покрытия
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (coveragePercent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.raised,
              valueColor: AlwaysStoppedAnimation<Color>(
                coveragePercent >= 80 ? AppColors.sage : AppColors.amber,
              ),
            ),
          ),
          SizedBox(height: 10),

          // Сводка основных фаз
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPhaseSummary('Глубокий', '${(sleepResult.actualSleepMinutes * 0.22 / 60).toStringAsFixed(1)}ч', AppColors.sage),
              _buildPhaseSummary('REM (быстрый)', '${(sleepResult.actualSleepMinutes * 0.24 / 60).toStringAsFixed(1)}ч', AppColors.amber),
              _buildPhaseSummary('Легкий', '${(sleepResult.actualSleepMinutes * 0.54 / 60).toStringAsFixed(1)}ч', AppColors.muted),
            ],
          ),
          SizedBox(height: 10),

          // Подсказка нажать для подробного разбора
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.raised.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.query_stats, size: 14, color: AppColors.amber),
                    SizedBox(width: 6),
                    Text(
                      'Подробный разбор фаз и долга сна',
                      style: TextStyle(
                        color: AppColors.fg,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.chevron_right, size: 16, color: AppColors.amber),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPhaseSummary(String label, String value, Color dotColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
          ),
        ),
        SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(color: AppColors.muted, fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(color: AppColors.fg, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  static Widget _buildNeedItem(String label, String val, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.faint, fontSize: 9)),
        SizedBox(height: 2),
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

  static Widget _buildFactorPill(String title, String val) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.raised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Text(val, style: TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.muted, fontSize: 8.5),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        SizedBox(width: 4),
        Text(label, style: TextStyle(color: AppColors.muted, fontSize: 9)),
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
