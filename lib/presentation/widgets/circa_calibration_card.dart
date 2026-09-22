import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/circa_haptics.dart';
import 'glass_card.dart';

/// Карточка первой 14-дневной калибровки физиологической базы KALKAN
/// Лаконичный внешний вид с детальной модальной шторкой.
/// Автоматически исчезает, когда калибровка завершена (currentDay >= totalDays).
class CircaCalibrationCard extends StatelessWidget {
  final int currentDay;
  final int totalDays;
  final VoidCallback? onTap;

  const CircaCalibrationCard({
    super.key,
    this.currentDay = 3,
    this.totalDays = 14,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Если калибровка уже завершена (14 из 14 дней), полностью скрываем карточку
    if (currentDay >= totalDays) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap ?? () => _showCalibrationInfoSheet(context, currentDay, totalDays),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderColor: AppColors.amber.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Лаконичный хедер: название и день
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.amber,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'КАЛИБРОВКА БАЗЫ',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
                Spacer(),
                Text(
                  'День $currentDay из $totalDays',
                  style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),

            // 14-сегментный прогресс-бар
            Row(
              children: List.generate(totalDays, (index) {
                final isDone = index < currentDay;
                final isCurrent = index == currentDay - 1;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: index == totalDays - 1 ? 0 : 3),
                    decoration: BoxDecoration(
                      color: isDone
                          ? (isCurrent ? AppColors.amber : AppColors.sage)
                          : AppColors.line.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 10),

            // Минималистичная подсказка для тапа
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Формирование нормы СААТ-1',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Подробнее',
                      style: TextStyle(
                        color: AppColors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 9, color: AppColors.amber),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void _showCalibrationInfoSheet(BuildContext context, int currentDay, int totalDays) {
    CircaHaptics.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                Text(
                  '14-ДНЕВНЫЙ ПРОТОКОЛ КАЛИБРОВКИ',
                  style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Формирование биометрической нормы',
                  style: TextStyle(
                    color: AppColors.fg,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    'В течение первых 14 дней сенсоры KALKAN СААТ-1 изучают индивидуальный вариабельный коридор ВСР и ночного пульса. Базовая точность персональных рекомендаций фиксируется на 14-й день.',
                    style: TextStyle(
                      color: AppColors.fg,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 14),

                // Микро-метрики текущей точности в модальном окне
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CalibrationMiniTag(
                        label: 'ВСР покоя',
                        value: 'Записано $currentDay ночей',
                        isReady: currentDay >= 3,
                      ),
                      _CalibrationMiniTag(
                        label: 'Сон и циклы',
                        value: '${((currentDay / totalDays) * 100).toInt()}% точности',
                        isReady: currentDay >= 7,
                      ),
                      _CalibrationMiniTag(
                        label: 'Ритмы ЦНС',
                        value: currentDay >= 14 ? 'Готово' : 'Обучение',
                        isReady: currentDay >= 14,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: AppColors.stage,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'ПОНЯТНО',
                      style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.0, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CalibrationMiniTag extends StatelessWidget {
  final String label;
  final String value;
  final bool isReady;

  const _CalibrationMiniTag({
    required this.label,
    required this.value,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2),
        Row(
          children: [
            Icon(
              isReady ? Icons.check_circle_outline : Icons.timelapse,
              size: 11,
              color: isReady ? AppColors.sage : AppColors.amber,
            ),
            SizedBox(width: 3),
            Text(
              value,
              style: TextStyle(
                color: isReady ? AppColors.fg : AppColors.amber,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
