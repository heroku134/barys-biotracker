import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/circa_haptics.dart';
import '../../domain/intelligence/menstrual_cycle_engine.dart';
import '../../domain/models/telemetry.dart';
import '../../domain/models/user_profile.dart';
import 'kalkan_ui.dart';

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
        final palette = KalkanColors.of(context);

        // Если дата последних месячных не указана — не генерируем ложный 14-й день
        if (profile.lastPeriodStartDate == null) {
          return GestureDetector(
            onTap: () {
              CircaHaptics.selectionClick();
              onTap();
            },
            child: KalkanCard(
              padding: const EdgeInsets.all(KalkanUi.cardPadding),
              borderColor: AppColors.rose.withValues(alpha: 0.35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.rose.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.rose.withValues(alpha: 0.35), width: KalkanUi.hairline),
                        ),
                        child: const Icon(Icons.female, color: AppColors.rose, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.tr('cycle_card_header', language),
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        AppLocaleNotifier.pick('Настроить →', 'Жөндөө →', 'Setup →'),
                        style: const TextStyle(
                          color: AppColors.rose,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocaleNotifier.pick('Цикл не настроен', 'Цикл жөндөлө элек', 'Cycle not configured'),
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocaleNotifier.pick(
                      'Укажите дату последних месячных для точного расчёта фаз, прогноза фертильности и адаптивной нагрузки СААТ-1.',
                      'Фазаларды, фертилдүүлүктү жана машыгуу жүктөмүн так эсептөө үчүн акыркы этек кирдин күнүн белгилеңиз.',
                      'Set your last period date for accurate cycle phases, fertility predictions, and adaptive SAAT-1 strain targets.',
                    ),
                    style: TextStyle(
                      color: palette.secondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        CircaHaptics.selectionClick();
                        onTap();
                      },
                      icon: const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.rose),
                      label: Text(
                        AppLocaleNotifier.pick('Указать дату начала', 'Башталыш күнүн тандоо', 'Set Start Date'),
                        style: const TextStyle(color: AppColors.rose, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.rose.withValues(alpha: 0.5), width: KalkanUi.hairline),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KalkanUi.controlRadius)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

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
          child: KalkanCard(
            padding: const EdgeInsets.all(KalkanUi.cardPadding),
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
                      children: [
                        Text(
                          AppLocaleNotifier.pick('Инфо', 'Маалымат', 'Info'),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.muted),
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
                      '/ ${analysis.totalDays} ${AppLocaleNotifier.pick('день', 'күн', 'day')}',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    // Бейдж текущей фазы вместо непонятного чипа градусов
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: pColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
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
                    borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                    border: Border.all(color: AppColors.line.withValues(alpha: 0.8)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocaleNotifier.pick(
                            'Пик выносливости и сил · Подробнее →',
                            'Күч жана чыдамкайлыктын туу чокусу · Кененирээк →',
                            'Peak stamina and strength · Details →',
                          ),
                          style: TextStyle(
                            color: AppColors.fg,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.amber, size: 18),
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
                borderRadius: BorderRadius.circular(KalkanUi.progressRadius),
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
