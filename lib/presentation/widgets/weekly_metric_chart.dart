import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../data/history/biometrics_history_repository.dart';

class WeeklyMetricChart extends StatelessWidget {
  final String title;
  final String unit;
  final List<HistoricalPoint> points;
  final Color color;
  final double maxValue;

  const WeeklyMetricChart({
    super.key,
    required this.title,
    required this.unit,
    required this.points,
    required this.color,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final last = points.isEmpty ? 0.0 : points.last.value;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTypography.bodySemibold(palette.fg))),
              Text('${last.toStringAsFixed(last >= 20 ? 0 : 1)} $unit', style: AppTypography.metricValue(color)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 92,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in points)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: (p.value / maxValue).clamp(0.06, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(p.label, style: AppTypography.caption(palette.muted).copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
