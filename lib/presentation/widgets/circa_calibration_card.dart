import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/circa_haptics.dart';
import '../../data/storage/calibration_store.dart';
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

    final palette = KalkanColors.of(context);
    final displayDay = currentDay <= 0 ? 1 : currentDay;

    return GestureDetector(
      onTap: onTap ?? () => _showCalibrationInfoSheet(context, displayDay, totalDays),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderColor: AppColors.amber.withValues(alpha: 0.35),
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
                const SizedBox(width: 8),
                Text(
                  'КАЛИБРОВКА БАЗЫ',
                  style: TextStyle(
                    color: palette.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
                const Spacer(),
                Text(
                  'День $displayDay из $totalDays',
                  style: const TextStyle(
                    color: AppColors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 14-сегментный прогресс-бар
            Row(
              children: List.generate(totalDays, (index) {
                final isDone = index < displayDay;
                final isCurrent = index == displayDay - 1;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: index == totalDays - 1 ? 0 : 3),
                    decoration: BoxDecoration(
                      color: isDone
                          ? (isCurrent ? AppColors.amber : AppColors.sage)
                          : palette.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),

            // Минималистичная подсказка для тапа
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Формирование нормы СААТ-1',
                  style: TextStyle(
                    color: palette.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Row(
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
    final palette = KalkanColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                          color: palette.hairline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '14-ДНЕВНЫЙ ПРОТОКОЛ КАЛИБРОВКИ',
                      style: TextStyle(
                        color: AppColors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Формирование биометрической нормы',
                      style: TextStyle(
                        color: palette.fg,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.raised,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: palette.hairline),
                      ),
                      child: Text(
                        'В течение первых 14 дней сенсоры KALKAN СААТ-1 изучают индивидуальный вариабельный коридор ВСР и ночного пульса. Базовая точность персональных рекомендаций фиксируется на 14-й день.',
                        style: TextStyle(
                          color: palette.fg,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Микро-метрики текущей точности в модальном окне
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: palette.raised,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: palette.hairline),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _CalibrationMiniTag(
                            label: 'ВСР покоя',
                            value: 'Записано $currentDay ночей',
                            isReady: currentDay >= 3,
                            palette: palette,
                          ),
                          _CalibrationMiniTag(
                            label: 'Сон и циклы',
                            value: '${((currentDay / totalDays) * 100).toInt()}% точности',
                            isReady: currentDay >= 7,
                            palette: palette,
                          ),
                          _CalibrationMiniTag(
                            label: 'Ритмы ЦНС',
                            value: currentDay >= 14 ? 'Готово' : 'Обучение',
                            isReady: currentDay >= 14,
                            palette: palette,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final next = (currentDay % 14) + 1;
                              await CalibrationStore.setCalibrationDays(next);
                              CircaHaptics.selectionClick();
                              if (context.mounted) Navigator.of(ctx).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.fg,
                              side: BorderSide(color: palette.hairline),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('+1 ДЕНЬ (ТЕСТ)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
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
                            child: const Text(
                              'ПОНЯТНО',
                              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.0, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CalibrationMiniTag extends StatelessWidget {
  final String label;
  final String value;
  final bool isReady;
  final KalkanColors palette;

  const _CalibrationMiniTag({
    required this.label,
    required this.value,
    required this.isReady,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.secondary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(
              isReady ? Icons.check_circle_outline : Icons.timelapse,
              size: 11,
              color: isReady ? AppColors.sage : AppColors.amber,
            ),
            const SizedBox(width: 3),
            Text(
              value,
              style: TextStyle(
                color: isReady ? palette.fg : AppColors.amber,
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
