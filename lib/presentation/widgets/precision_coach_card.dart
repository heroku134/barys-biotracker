import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import 'precision_card.dart';

/// Athletic coaching insight card (Swiss typographic layout)
/// - Plain grotesk with confident whitespace
/// - Strict grid, zero ornamentation
/// - Regular (w400) and Semibold (w600) weights only
class PrecisionCoachCard extends StatelessWidget {
  final String title;
  final String insight;
  final String actionLabel;
  final Color accentColor;
  final VoidCallback? onTap;

  const PrecisionCoachCard({
    super.key,
    this.title = 'DAILY INSIGHT',
    required this.insight,
    this.actionLabel = 'Можно тренироваться',
    this.accentColor = AppColors.sage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PrecisionCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.monoLabel(),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.raised,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.hairline, width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 5),
                    Text(
                      actionLabel,
                      style: AppTypography.monoBadge().copyWith(
                        color: accentColor,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            insight,
            style: AppTypography.body().copyWith(
              color: AppColors.textNearWhite,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
