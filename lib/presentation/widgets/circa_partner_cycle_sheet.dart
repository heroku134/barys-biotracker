import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/circa_haptics.dart';
import '../../data/storage/partner_cycle_repository.dart';
import '../../domain/models/partner_cycle_data.dart';
import 'glass_card.dart';

/// Модальный экран глубокого анализа биоритма партнёрши и советов для партнёра
class CircaPartnerCycleSheet extends StatelessWidget {
  final PartnerCycleData data;

  const CircaPartnerCycleSheet({super.key, required this.data});

  static void show(BuildContext context, PartnerCycleData data) {
    CircaHaptics.sheetOpen();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CircaPartnerCycleSheet(data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pColor = data.phaseColor;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.stage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.lineStrong, width: 1.2)),
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Верхняя полоска-индикатор
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 14),

            // Заголовок и кнопка закрытия
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.favorite, color: AppColors.rose, size: 18),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Биоритм: ${data.partnerName}',
                        style: TextStyle(
                          color: AppColors.fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'День ${data.cycleDay} из ${data.cycleLength} · СААТ-1 Синхронизация',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.muted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Главная карточка фазы и статуса
            GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: pColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: pColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          data.phaseTitle,
                          style: TextStyle(
                            color: pColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Text(
                        '${data.skinTempDeviation >= 0 ? '+' : ''}${data.skinTempDeviation.toStringAsFixed(2)}°C к норме',
                        style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),

                  // Показатели: Энергия, Настроение, Выделения
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          label: 'ЭНЕРГИЯ',
                          value: '${data.energyEmoji} ${data.energyScore}/5',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'НАСТРОЕНИЕ',
                          value: data.mood,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 14),

            // Совет для партнёра на сегодня
            GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: AppColors.amber, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'КАК ПОДДЕРЖАТЬ СЕГОДНЯ',
                        style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    data.partnerGuidance,
                    style: TextStyle(
                      color: AppColors.fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14),

            // Отмеченные симптомы (если есть)
            if (data.symptoms.isNotEmpty) ...[
              GlassCard(
                borderRadius: 18,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ОТМЕЧЕНО ПАРТНЁРШЕЙ',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: data.symptoms.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.raised,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              color: AppColors.fg,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14),
            ],

            // Кнопки управления
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: 'Статус биоритма ${data.partnerName}: фаза ${data.phaseTitle}, день ${data.cycleDay}. ${data.partnerGuidance}',
                      ));
                      CircaHaptics.success();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Совет для партнёра скопирован в буфер'),
                          backgroundColor: AppColors.surface,
                        ),
                      );
                    },
                    icon: Icon(Icons.copy, size: 14, color: AppColors.fg),
                    label: Text(
                      'Скопировать',
                      style: TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.line),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: Text('Отвязать партнёра?', style: TextStyle(color: AppColors.fg, fontSize: 16)),
                          content: Text(
                            'Карточка партнёра будет скрыта с главного экрана.',
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text('ОТМЕНА', style: TextStyle(color: AppColors.muted)),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.rose,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('ОТВЯЗАТЬ'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await PartnerCycleRepository.unlinkPartner();
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                    icon: Icon(Icons.link_off, size: 14, color: AppColors.rose),
                    label: Text(
                      'Отвязать',
                      style: TextStyle(color: AppColors.rose, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.faint, fontSize: 9, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(color: AppColors.fg, fontSize: 12.5, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
