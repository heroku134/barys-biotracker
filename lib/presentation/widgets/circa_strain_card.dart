import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../domain/intelligence/strain_engine.dart';
import 'glass_card.dart';

class CircaStrainCard extends StatelessWidget {
  final StrainCalculationResult strainResult;
  final VoidCallback? onOpenWorkout;

  const CircaStrainCard({
    super.key,
    required this.strainResult,
    this.onOpenWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final current = strainResult.currentStrain;
    final targetMin = strainResult.targetStrainMin;
    final targetMax = strainResult.targetStrainMax;

    // Цвет акцента нагрузки (умеренно - циановый/янтарный, высокий - янтарный/розовый)
    final Color strainColor;
    if (current >= 18.0) {
      strainColor = AppColors.rose;
    } else if (current >= 14.0) {
      strainColor = AppColors.amber;
    } else {
      strainColor = AppColors.sage;
    }

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
                      color: strainColor,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'НАГРУЗКА (STRAIN)',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.raised,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  'Цель: ${targetMin.toStringAsFixed(1)}–${targetMax.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: AppColors.fg,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Цифра Strain и статус бюджета
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                current.toStringAsFixed(1),
                style: TextStyle(
                  color: strainColor,
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.5,
                  height: 1.0,
                ),
              ),
              Text(
                ' / 21.0',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      strainResult.budgetStatusText,
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: strainResult.isInTargetZone ? AppColors.sage : AppColors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Шкала TRIMP (Whoop)',
                      style: TextStyle(
                        color: AppColors.faint,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          // Шкала 0–21 с целевым окном
          Stack(
            children: [
              // Фон шкалы
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.raised,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Целевой коридор (подсветка допустимого диапазона)
              Positioned(
                left: (targetMin / 21.0) * MediaQuery.of(context).size.width * 0.8,
                right: ((21.0 - targetMax) / 21.0) * MediaQuery.of(context).size.width * 0.8,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.sage.withValues(alpha: 0.5), width: 1),
                  ),
                ),
              ),
              // Заполнение текущего Strain
              FractionallySizedBox(
                widthFactor: (current / 21.0).clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: strainColor,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: strainColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // 5 зон пульса (TRIMP)
          Text(
            'ВРЕМЯ В ПУЛЬСОВЫХ ЗОНАХ (ЧСС)',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          SizedBox(height: 8),

          _buildZonesDistribution(strainResult.zoneMinutes),
          SizedBox(height: 12),

          // Автодетектированная тренировка
          if (strainResult.dailyActivities.isNotEmpty) ...[
            Divider(color: AppColors.line, height: 1),
            SizedBox(height: 10),
            for (final act in strainResult.dailyActivities)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.raised,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.directions_run, size: 16, color: AppColors.amber),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              act.title,
                              style: TextStyle(
                                color: AppColors.fg,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (act.isAutoDetected) ...[
                              SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.sage.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'АВТОДЕТЕКТ',
                                  style: TextStyle(
                                    color: AppColors.sage,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${act.durationMinutes} мин · Ср. пульс ${act.avgHeartRate} bpm · +${act.caloriesBurned} ккал',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${act.activityStrain.toStringAsFixed(1)} Strain',
                    style: TextStyle(
                      color: AppColors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildZonesDistribution(List<int> zones) {
    const zoneNames = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'];
    const zoneColors = [
      AppColors.muted,
      AppColors.sage,
      AppColors.sage,
      AppColors.amber,
      AppColors.rose,
    ];

    final safeZones = zones.length >= 5 ? zones : [60, 40, 20, 10, 2];
    final maxMinutes = safeZones.fold<int>(0, (a, b) => a > b ? a : b);
    final safeMax = maxMinutes <= 0 ? 1 : maxMinutes;

    return Row(
      children: [
        for (var i = 0; i < 5; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  Container(
                    height: 32,
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: (safeZones[i] / safeMax).clamp(0.15, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: zoneColors[i],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${safeZones[i]}м',
                    style: TextStyle(
                      color: AppColors.fg,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    zoneNames[i],
                    style: TextStyle(
                      color: zoneColors[i],
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
