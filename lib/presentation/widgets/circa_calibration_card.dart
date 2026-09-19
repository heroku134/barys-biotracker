import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'glass_card.dart';

/// Карточка первой 14-дневной калибровки физиологической базы CIRCA (Commitment Device)
/// Мотивирует пользователя носить браслет и формирует привычку с первых дней.
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
    final progressPercent = ((currentDay / totalDays) * 100).toInt();
    final remainingDays = totalDays - currentDay;

    return GestureDetector(
      onTap: onTap ?? () => _showCalibrationInfoSheet(context),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        borderColor: AppColors.amber.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Хедер: статус + индикатор
            Row(
              children: [
                // Пульсирующая точка статуса калибровки
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.amber,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.amber,
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'КАЛИБРОВКА БАЗЫ · ЭТАП ОБУЧЕНИЯ',
                    style: TextStyle(
                      color: AppColors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$progressPercent% ГОТОВО',
                    style: const TextStyle(
                      color: AppColors.amber,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Крупный заголовок дня
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'День $currentDay',
                  style: const TextStyle(
                    color: AppColors.fg,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  ' из $totalDays',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  'Осталось $remainingDays дн.',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 14-сегментный прогресс-бар в стиле швейцарской типографики
            Row(
              children: List.generate(totalDays, (index) {
                final isDone = index < currentDay;
                final isCurrent = index == currentDay - 1;
                return Expanded(
                  child: Container(
                    height: 5,
                    margin: EdgeInsets.only(right: index == totalDays - 1 ? 0 : 3),
                    decoration: BoxDecoration(
                      color: isDone
                          ? (isCurrent ? AppColors.amber : AppColors.sage)
                          : AppColors.line.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2.5),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: AppColors.amber.withValues(alpha: 0.6),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),

            // Описание ценности (commitment device)
            const Text(
              'CIRCA изучает индивидуальный вариабельный коридор ВСР и ночного пульса. Базовая точность персональных рекомендаций зафиксируется через 11 дней.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),

            // Микро-метрики текущей точности
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.raised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line.withValues(alpha: 0.6)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CalibrationMiniTag(label: 'ВСР покоя', value: 'Записано 3 ночи', isReady: true),
                  _CalibrationMiniTag(label: 'Сон и циклы', value: '78% точности', isReady: true),
                  _CalibrationMiniTag(label: 'Циркадный ритм', value: 'Калибровка', isReady: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showCalibrationInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
                const SizedBox(height: 18),
                const Text(
                  '14-ДНЕВНЫЙ ПРОТОКОЛ КАЛИБРОВКИ',
                  style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Как CIRCA формирует вашу биометрическую норму',
                  style: TextStyle(
                    color: AppColors.fg,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Каждый организм уникален. Универсальные таблицы пульса и ВСР не дают точной картины для профессиональных атлетов и биохакеров.\n\n'
                  'В течение первых 14 дней алгоритмы CIRCA вычисляют вашу персональную медиану вегетативного тонуса, базовую температуру кожи и суточные колебания кортизола/мелатонина.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: AppColors.stage,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Понятно, продолжать калибровку',
                      style: TextStyle(fontWeight: FontWeight.w800),
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
          style: const TextStyle(
            color: AppColors.muted,
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
