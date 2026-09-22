import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import 'precision_card.dart';

/// Sleep summary card with Swiss precision layout (Whoop 5.0 / Oura standard)
/// - Flat surface (#0E1015) with 1px hairline border (#1C2029)
/// - Tabular figures hero duration
/// - Monospace stage labels and percentages
/// - Zero glow, zero glass, zero shadows
class PrecisionSleepCard extends StatelessWidget {
  final int totalMinutes;
  final int deepMinutes;
  final int remMinutes;
  final int lightMinutes;
  final int awakeMinutes;
  final int sleepPerformanceScore;
  final VoidCallback? onTap;

  const PrecisionSleepCard({
    super.key,
    this.totalMinutes = 468, // 7h 48m
    this.deepMinutes = 102,  // 1h 42m
    this.remMinutes = 116,   // 1h 56m
    this.lightMinutes = 224, // 3h 44m
    this.awakeMinutes = 26,  // 26m
    this.sleepPerformanceScore = 88,
    this.onTap,
  });

  String _formatHoursMins(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}M';
    return '${h}H ${m.toString().padLeft(2, '0')}M';
  }

  @override
  Widget build(BuildContext context) {
    final total = (deepMinutes + remMinutes + lightMinutes + awakeMinutes).toDouble();
    final deepFrac = total > 0 ? deepMinutes / total : 0.22;
    final remFrac = total > 0 ? remMinutes / total : 0.25;
    final lightFrac = total > 0 ? lightMinutes / total : 0.48;
    final awakeFrac = total > 0 ? awakeMinutes / total : 0.05;

    return PrecisionCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Monospace Title & Performance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SLEEP SUMMARY',
                style: AppTypography.monoLabel(),
              ),
              Row(
                children: [
                  Text(
                    'PERFORMANCE  ',
                    style: AppTypography.monoLabel().copyWith(
                      fontSize: 9.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    '$sleepPerformanceScore%',
                    style: AppTypography.monoBadge().copyWith(
                      color: AppColors.sage,
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 12),

          // 2. Hero Duration Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatHoursMins(totalMinutes),
                style: AppTypography.heroNumberMedium().copyWith(
                  color: AppColors.textNearWhite,
                  fontSize: 32,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'TOTAL ASLEEP',
                style: AppTypography.monoUnit().copyWith(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
              Spacer(),
              Text(
                'EFFICIENCY 92%',
                style: AppTypography.monoBadge().copyWith(
                  fontSize: 9.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          SizedBox(height: 14),

          // 3. Segmented Flat Sleep Bar (Zero glow, exact color coding)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.hairline, width: 1.0),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: (deepFrac * 1000).round(),
                    child: Container(color: AppColors.sage), // Deep: sage
                  ),
                  Expanded(
                    flex: (remFrac * 1000).round(),
                    child: Container(color: AppColors.amber), // REM: amber
                  ),
                  Expanded(
                    flex: (lightFrac * 1000).round(),
                    child: Container(color: AppColors.textSecondary), // Light: secondary grey
                  ),
                  Expanded(
                    flex: (awakeFrac * 1000).round(),
                    child: Container(color: AppColors.rose), // Awake: muted rose
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 14),

          // 4. Strict 4-Column Stages Breakdown Grid
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.raised,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.hairline, width: 1.0),
            ),
            child: Row(
              children: [
                Expanded(child: _buildStageCol('DEEP', deepMinutes, AppColors.sage)),
                Container(width: 1, height: 24, color: AppColors.hairline),
                Expanded(child: _buildStageCol('REM', remMinutes, AppColors.amber)),
                Container(width: 1, height: 24, color: AppColors.hairline),
                Expanded(child: _buildStageCol('LIGHT', lightMinutes, AppColors.textSecondary)),
                Container(width: 1, height: 24, color: AppColors.hairline),
                Expanded(child: _buildStageCol('AWAKE', awakeMinutes, AppColors.rose)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageCol(String name, int mins, Color dotColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 4),
            Text(
              name,
              style: AppTypography.monoLabel().copyWith(
                fontSize: 8.5,
                letterSpacing: 1.0,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        SizedBox(height: 3),
        Text(
          _formatHoursMins(mins),
          style: AppTypography.metricValue().copyWith(
            fontSize: 11,
            color: AppColors.textNearWhite,
          ),
        ),
      ],
    );
  }
}
