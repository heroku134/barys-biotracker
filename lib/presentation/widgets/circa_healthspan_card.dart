import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/circa_haptics.dart';
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
      onTap: () => _showHealthspanDetailModal(context),
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
                  SizedBox(width: 8),
                  Text(
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
                  style: TextStyle(
                    color: AppColors.sage,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Главное число: Биологический возраст
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                healthspan.circaBiologicalAge.toStringAsFixed(1),
                style: TextStyle(
                  color: AppColors.fg,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              Text(
                ' года',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
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
          SizedBox(height: 4),
          Text(
            'Паспортный возраст: ${healthspan.chronologicalAge} лет',
            style: TextStyle(
              color: AppColors.faint,
              fontSize: 11,
            ),
          ),
          SizedBox(height: 10),

          // Лаконичная строка-приглашение к просмотру подробностей
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.raised.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Icon(Icons.insights, size: 14, color: AppColors.sage),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Подробнее о факторах долголетия и биомаркерах',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHealthspanDetailModal(BuildContext context) {
    CircaHaptics.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.health_and_safety_outlined, color: AppColors.sage, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'ФАКТОРЫ ДОЛГОЛЕТИЯ (HEALTHSPAN)',
                      style: TextStyle(
                        color: AppColors.sage,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'VO2max: ${healthspan.estimatedVo2Max}',
                    style: TextStyle(color: AppColors.sage, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Сетка 4 биомаркеров долголетия
            Row(
              children: [
                _buildFactorItem('Аэробная Z2', '${healthspan.weeklyZone2Minutes}м/нед', 'Митохондрии'),
                SizedBox(width: 6),
                _buildFactorItem('Интервалы Z5', '${healthspan.weeklyZone5Minutes}м/нед', 'Ударный объем'),
                SizedBox(width: 6),
                _buildFactorItem('Тренд пульса', '${healthspan.rhrSixMonthTrend} bpm', 'За 6 месяцев'),
                SizedBox(width: 6),
                _buildFactorItem('Сон', '${healthspan.sleepConsistencyPercent.round()}%', 'Восстановление'),
              ],
            ),
            SizedBox(height: 16),

            // Подробное физиологическое объяснение
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.raised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                healthspan.physiologicalDetails,
                style: TextStyle(
                  color: AppColors.fg,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
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
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              val,
              style: TextStyle(
                color: AppColors.fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 1),
            Text(
              sub,
              style: TextStyle(
                color: AppColors.faint,
                fontSize: 7.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
