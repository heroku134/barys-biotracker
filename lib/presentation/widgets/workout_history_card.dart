import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../domain/models/workout_session.dart';
import 'glass_card.dart';

/// Виджет элемента истории тренировок
class WorkoutHistoryCard extends StatelessWidget {
  final CompletedWorkout workout;
  final VoidCallback? onTap;

  const WorkoutHistoryCard({
    super.key,
    required this.workout,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final w = workout;

    return GlassCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.25), width: 1.0),
            ),
            child: Icon(w.sport.icon, color: AppColors.amber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      w.sport.title,
                      style: TextStyle(color: palette.fg, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    if (w.isExternal) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: w.sourceColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: w.sourceColor.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(w.sourceIcon, size: 10, color: w.sourceColor),
                            const SizedBox(width: 3),
                            Text(
                              w.sourceDisplayName,
                              style: TextStyle(color: w.sourceColor, fontSize: 9, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${w.durationFormatted}${w.distanceKm > 0 ? " · ${w.distanceKm.toStringAsFixed(2)} км" : ""} · ${w.calories} ккал',
                  style: TextStyle(color: palette.secondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${w.strain.toStringAsFixed(1)}',
                style: const TextStyle(color: AppColors.sage, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Text(
                w.avgHr > 0 ? '${w.avgHr} bpm' : '-- bpm',
                style: TextStyle(color: palette.secondary, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 16, color: palette.muted),
        ],
      ),
    );
  }
}
