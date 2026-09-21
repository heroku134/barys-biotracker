import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/circa_haptics.dart';
import '../../domain/intelligence/menstrual_cycle_engine.dart';
import '../../domain/models/telemetry.dart';
import '../../domain/models/user_profile.dart';
import 'glass_card.dart';

/// Виджет-карточка менструального цикла на главном экране (активна строго для женского пола)
class CircaCycleCard extends StatelessWidget {
  final BleTelemetry telemetry;
  final UserProfile profile;
  final VoidCallback onTap;

  const CircaCycleCard({
    super.key,
    required this.telemetry,
    required this.profile,
    required this.onTap,
  });

  Color _phaseColor(HormonalCyclePhase phase) {
    switch (phase) {
      case HormonalCyclePhase.menstrual:
        return AppColors.rose;
      case HormonalCyclePhase.follicular:
        return AppColors.sage;
      case HormonalCyclePhase.ovulatory:
        return AppColors.amber;
      case HormonalCyclePhase.luteal:
        return const Color(0xFFA685B8); // Благородный лавандово-лиловый оттенок
    }
  }

  String _phaseName(HormonalCyclePhase phase, AppLanguage language) {
    switch (phase) {
      case HormonalCyclePhase.menstrual:
        return AppStrings.tr('cycle_phase_menstrual', language);
      case HormonalCyclePhase.follicular:
        return AppStrings.tr('cycle_phase_follicular', language);
      case HormonalCyclePhase.ovulatory:
        return AppStrings.tr('cycle_phase_ovulatory', language);
      case HormonalCyclePhase.luteal:
        return AppStrings.tr('cycle_phase_luteal', language);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        final analysis = MenstrualCycleEngine.analyze(
          telemetry: telemetry,
          profile: profile,
          language: language,
        );

        final pColor = _phaseColor(analysis.phase);

        return GestureDetector(
          onTap: () {
            CircaHaptics.ringZoneTick();
            onTap();
          },
          child: GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Шапка: Брендинг СААТ-1 и индикатор фазы
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: pColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: pColor.withValues(alpha: 0.35), width: 1),
                          ),
                          child: Icon(Icons.female, color: pColor, size: 14),
                        ),
                        SizedBox(width: 8),
                        Text(
                          AppStrings.tr('cycle_card_header', language),
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Инфо',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.muted),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Основная строка: День цикла + Фаза биоритма
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${analysis.currentDay}',
                      style: TextStyle(
                        color: pColor,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '/ ${analysis.totalDays} ${language == AppLanguage.kyrgyz ? 'күн' : 'день'}',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Бейдж текущей фазы вместо непонятного чипа градусов
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: pColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: pColor.withValues(alpha: 0.35), width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: pColor,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            _phaseName(analysis.phase, language),
                            style: TextStyle(
                              color: pColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // 28-дневная линейка биоритма
                _buildCycleTimeline(analysis.currentDay, analysis.totalDays, pColor),
                SizedBox(height: 12),

                // Лаконичная директива по нагрузке и восстановлению
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line.withValues(alpha: 0.8)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          language == AppLanguage.kyrgyz
                              ? 'Күч жана чыдамкайлыктын туу чокусу · Кененирээк →'
                              : 'Пик выносливости и сил · Подробнее →',
                          style: TextStyle(
                            color: AppColors.fg,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.amber, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCycleTimeline(int currentDay, int totalDays, Color activeColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalTicks = totalDays.clamp(20, 35);
        final itemWidth = (constraints.maxWidth - (totalTicks - 1) * 2) / totalTicks;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(totalTicks, (index) {
            final day = index + 1;
            final isCurrent = day == currentDay;
            final isPast = day < currentDay;

            // Цветовая разметка фаз в полосе
            Color tickColor;
            if (day <= 5) {
              tickColor = AppColors.rose.withValues(alpha: isPast || isCurrent ? 0.9 : 0.35);
            } else if (day < 14) {
              tickColor = AppColors.sage.withValues(alpha: isPast || isCurrent ? 0.9 : 0.35);
            } else if (day <= 16) {
              tickColor = AppColors.amber.withValues(alpha: isPast || isCurrent ? 0.9 : 0.35);
            } else {
              tickColor = const Color(0xFFA685B8).withValues(alpha: isPast || isCurrent ? 0.9 : 0.35);
            }

            return Container(
              width: itemWidth.clamp(2.0, 10.0),
              height: isCurrent ? 14 : 6,
              decoration: BoxDecoration(
                color: isCurrent ? activeColor : tickColor,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        );
      },
    );
  }
}
