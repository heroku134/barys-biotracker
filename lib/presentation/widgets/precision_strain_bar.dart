import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import 'precision_card.dart';

/// Daily strain bar with numeric target range (Whoop 5.0 Athletic style)
/// - Warm amber accent (#DE8A36)
/// - Geometric grotesk hero strain load with tabular figures
/// - Monospace labels and units
/// - Clean flat progress track with target range corridor
class PrecisionStrainBar extends StatelessWidget {
  final double currentStrain;
  final double maxStrain;
  final double targetMin;
  final double targetMax;
  final int activeCalories;
  final int activeMinutes;
  final VoidCallback? onTap;

  const PrecisionStrainBar({
    super.key,
    required this.currentStrain,
    this.maxStrain = 21.0,
    this.targetMin = 10.5,
    this.targetMax = 13.8,
    this.activeCalories = 1840,
    this.activeMinutes = 52,
    this.onTap,
  });

  String get _statusLabel {
    if (currentStrain < targetMin) return 'BUILDING LOAD';
    if (currentStrain <= targetMax) return 'IN TARGET ZONE';
    return 'OVERREACHING';
  }

  @override
  Widget build(BuildContext context) {
    final progress = (currentStrain / maxStrain).clamp(0.0, 1.0);
    final targetStartFrac = (targetMin / maxStrain).clamp(0.0, 1.0);
    final targetEndFrac = (targetMax / maxStrain).clamp(0.0, 1.0);

    return PrecisionCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Monospace Title & Target Range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DAY STRAIN',
                style: AppTypography.monoLabel,
              ),
              Row(
                children: [
                  Text(
                    'TARGET  ',
                    style: AppTypography.monoLabel.copyWith(
                      fontSize: 9.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    '${targetMin.toStringAsFixed(1)} — ${targetMax.toStringAsFixed(1)}',
                    style: AppTypography.monoBadge.copyWith(
                      color: AppColors.amber,
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 12),

          // 2. Hero Metric Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                currentStrain.toStringAsFixed(1),
                style: AppTypography.heroNumberMedium.copyWith(
                  color: AppColors.amber,
                  fontSize: 36,
                ),
              ),
              SizedBox(width: 6),
              Text(
                '/ ${maxStrain.toStringAsFixed(1)}',
                style: AppTypography.monoUnit.copyWith(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.raised,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.hairline, width: 1.0),
                ),
                child: Text(
                  _statusLabel,
                  style: AppTypography.monoBadge.copyWith(
                    color: AppColors.amber,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 14),

          // 3. Flat Precision Progress Track with Target Bracket
          SizedBox(
            height: 10,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth;
                final fillWidth = barWidth * progress;
                final targetLeft = barWidth * targetStartFrac;
                final targetWidth = barWidth * (targetEndFrac - targetStartFrac);

                return Stack(
                  children: [
                    // Background track
                    Container(
                      width: barWidth,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.raised,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: AppColors.hairline, width: 1.0),
                      ),
                    ),

                    // Target range shaded corridor
                    Positioned(
                      left: targetLeft,
                      width: targetWidth,
                      top: 1,
                      bottom: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.18),
                          border: Border(
                            left: BorderSide(color: AppColors.amber.withValues(alpha: 0.6), width: 1.0),
                            right: BorderSide(color: AppColors.amber.withValues(alpha: 0.6), width: 1.0),
                          ),
                        ),
                      ),
                    ),

                    // Active Amber Strain Fill (Flat, 0 glow)
                    if (progress > 0)
                      Positioned(
                        left: 0,
                        width: fillWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.amber,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          SizedBox(height: 12),

          // 4. Monospace Data Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDataUnit('ACTIVE CALORIES', '$activeCalories', 'KCAL'),
              _buildDataUnit('ACTIVE TIME', '$activeMinutes', 'MIN'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataUnit(String label, String value, String unit) {
    return Row(
      children: [
        Text(
          '$label  ',
          style: AppTypography.monoLabel.copyWith(
            fontSize: 9,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: AppTypography.metricValue.copyWith(
            fontSize: 12,
            color: AppColors.textNearWhite,
          ),
        ),
        SizedBox(width: 2),
        Text(
          unit,
          style: AppTypography.monoUnit.copyWith(
            fontSize: 9,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
