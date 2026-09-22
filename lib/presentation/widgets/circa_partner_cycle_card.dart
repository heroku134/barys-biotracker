import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../domain/models/partner_cycle_data.dart';
import 'glass_card.dart';

/// Карточка «Партнёр» на главном экране (отображение данных и советов по биоритму партнёрши)
class CircaPartnerCycleCard extends StatelessWidget {
  final PartnerCycleData data;
  final VoidCallback onTap;

  const CircaPartnerCycleCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = KalkanColors.of(context);
    final pColor = data.phaseColor;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        borderRadius: 22,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Шапка: Иконка сердца, Имя партнерши и бейдж фазы
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite,
                    color: AppColors.rose,
                    size: 15,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocaleNotifier.pick('Цикл · ${data.partnerName}', 'Цикл · ${data.partnerName}', 'Cycle · ${data.partnerName}'),
                        style: TextStyle(
                          color: c.secondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        AppLocaleNotifier.pick('День ${data.cycleDay} из ${data.cycleLength}', '${data.cycleDay}-күн / ${data.cycleLength}', 'Day ${data.cycleDay} of ${data.cycleLength}'),
                        style: TextStyle(
                          color: c.fg,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: pColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: pColor.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    data.phaseTitle,
                    style: TextStyle(
                      color: pColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // 2. Индикатор прогресса цикла (28-дневная дорожка с отметкой текущего дня)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 5,
                child: Row(
                  children: [
                    // Менструальная фаза (1-5 дни: 18%)
                    Expanded(
                      flex: 5,
                      child: Container(color: AppColors.rose.withValues(alpha: data.cycleDay <= 5 ? 0.9 : 0.25)),
                    ),
                    SizedBox(width: 2),
                    // Фолликулярная (6-13 дни: 28%)
                    Expanded(
                      flex: 8,
                      child: Container(color: AppColors.sage.withValues(alpha: (data.cycleDay > 5 && data.cycleDay <= 13) ? 0.9 : 0.25)),
                    ),
                    SizedBox(width: 2),
                    // Овуляция (14-16 дни: 11%)
                    Expanded(
                      flex: 3,
                      child: Container(color: AppColors.amber.withValues(alpha: (data.cycleDay > 13 && data.cycleDay <= 16) ? 0.9 : 0.25)),
                    ),
                    SizedBox(width: 2),
                    // Лютеиновая (17-28 дни: 43%)
                    Expanded(
                      flex: 12,
                      child: Container(color: const Color(0xFFA685B8).withValues(alpha: data.cycleDay > 16 ? 0.9 : 0.25)),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),

            // 3. Блок метрик (Температура, Энергия, Настроение)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: c.raised,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocaleNotifier.pick('Кожа', 'Тери', 'Skin'),
                          style: TextStyle(color: c.muted, fontSize: 8.5, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 1),
                        Text(
                          '${data.skinTempDeviation >= 0 ? '+' : ''}${data.skinTempDeviation.toStringAsFixed(2)}°C',
                          style: TextStyle(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: c.raised,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocaleNotifier.pick('Энергия', 'Энергия', 'Energy'),
                          style: TextStyle(color: c.muted, fontSize: 8.5, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 1),
                        Text(
                          '${data.energyEmoji} ${data.energyScore}/5',
                          style: TextStyle(color: pColor, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: c.raised,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocaleNotifier.pick('Настроение', 'Маанай', 'Mood'),
                          style: TextStyle(color: c.muted, fontSize: 8.5, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 1),
                        Text(
                          data.mood.split(' ').first,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),

            // 4. Совет для партнера
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.raised.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.hairline),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: AppColors.amber, size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.partnerGuidance,
                      style: TextStyle(
                        color: c.fg,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (data.symptoms.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(data.symptoms.join(' · '), style: TextStyle(color: c.secondary, fontSize: 12, height: 1.3)),
            ],
            if (data.flow != 'none') ...[
              SizedBox(height: 6),
              Text('Выделения: ${data.flow}', style: TextStyle(color: c.secondary, fontSize: 12)),
            ],
            if (data.note.isNotEmpty) ...[
              SizedBox(height: 6),
              Text(data.note, style: TextStyle(color: c.fg, fontSize: 12, height: 1.35)),
            ],
            SizedBox(height: 8),

            // 5. Футер
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  AppLocaleNotifier.pick('Подробнее', 'Толугураак', 'Details'),
                  style: TextStyle(
                    color: c.secondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
