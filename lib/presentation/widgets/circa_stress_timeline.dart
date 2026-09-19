import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../domain/intelligence/stress_engine.dart';
import 'glass_card.dart';

class CircaStressTimeline extends StatelessWidget {
  final StressDaySummary stressSummary;

  const CircaStressTimeline({
    super.key,
    required this.stressSummary,
  });

  @override
  Widget build(BuildContext context) {
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: stressSummary.currentLevel.color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'МОНИТОР СТРЕССА (ВСР + ЧСС)',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: stressSummary.currentLevel.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stressSummary.currentLevel.label,
                  style: TextStyle(
                    color: stressSummary.currentLevel.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Сводка: Восстановление vs Стресс
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ВОССТАНОВЛЕНИЕ',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${stressSummary.minutesInRestoration ~/ 60}ч ${stressSummary.minutesInRestoration % 60}м',
                        style: const TextStyle(
                          color: AppColors.sage,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ВЫСОКИЙ СТРЕСС',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${stressSummary.minutesInHighStress} мин',
                        style: const TextStyle(
                          color: AppColors.rose,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Хронологическая лента дня
          const Text(
            'ХРОНОЛОГИЯ СТРЕССА СЕГОДНЯ',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),

          for (final slot in stressSummary.timeline)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 76,
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      slot.timeRange.split(' — ')[0],
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 3, right: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: slot.level.color,
                      boxShadow: [
                        BoxShadow(
                          color: slot.level.color.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              slot.contextTitle,
                              style: const TextStyle(
                                color: AppColors.fg,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${slot.stressScore}%',
                              style: TextStyle(
                                color: slot.level.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          slot.physiologicalNote,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            height: 1.25,
                          ),
                        ),
                      ],
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
