import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../domain/intelligence/healthspan_engine.dart';
import 'glass_card.dart';

class CircaHealthspanCard extends StatelessWidget {
  final HealthspanResult healthspan;

  const CircaHealthspanCard({
    super.key,
    required this.healthspan,
  });

  @override
  Widget build(BuildContext context) {
    final isYounger = healthspan.ageDeltaYears < 0;

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
                    'HEALTHSPAN · БИО-ВОЗРАСТ KALKAN',
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
                  color: AppColors.sage.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.sage.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'VO2max: ${healthspan.estimatedVo2Max}',
                  style: const TextStyle(
                    color: AppColors.sage,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Главное число: Биологический возраст
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                healthspan.circaBiologicalAge.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.fg,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              const Text(
                ' года',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isYounger ? AppColors.sage.withValues(alpha: 0.2) : AppColors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isYounger
                      ? '${healthspan.ageDeltaYears} года к паспорту'
                      : '+${healthspan.ageDeltaYears} года к паспорту',
                  style: TextStyle(
                    color: isYounger ? AppColors.sage : AppColors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Паспортный возраст: ${healthspan.chronologicalAge} лет',
            style: const TextStyle(
              color: AppColors.faint,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),

          // Сетка 4 биомаркеров долголетия
          Row(
            children: [
              _buildFactorItem('Аэробная Z2', '${healthspan.weeklyZone2Minutes}м/нед', 'Митохондрии'),
              const SizedBox(width: 6),
              _buildFactorItem('Интервалы Z5', '${healthspan.weeklyZone5Minutes}м/нед', 'Ударный объем'),
              const SizedBox(width: 6),
              _buildFactorItem('Тренд RHR', '${healthspan.rhrSixMonthTrend} bpm', 'За 6 месяцев'),
              const SizedBox(width: 6),
              _buildFactorItem('Сон (регулярность)', '${healthspan.sleepConsistencyPercent.round()}%', 'Клеточное омоложение'),
            ],
          ),
          const SizedBox(height: 10),

          // Пояснение
          Text(
            healthspan.physiologicalDetails,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorItem(String title, String val, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.raised,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              val,
              style: const TextStyle(
                color: AppColors.fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              sub,
              style: const TextStyle(
                color: AppColors.faint,
                fontSize: 7.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
