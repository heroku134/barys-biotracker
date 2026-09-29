import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';
import '../../core/circa_haptics.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/models/readiness.dart';

/// Виджет-витрина двух маскотов KALKAN на главной лицевой панели
/// Отображает вырезанную пару маскотов (Барыс в ак-калпаке и Барыса-атлетка) без фона
class CircaMascotHeroCard extends StatelessWidget {
  final AvatarVisualState state;
  final ReadinessResult readiness;
  final VoidCallback? onTap;

  const CircaMascotHeroCard({
    super.key,
    required this.state,
    required this.readiness,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final accentColor = readiness.zone.color;

    return GestureDetector(
      onTap: () {
        CircaHaptics.selectionClick();
        onTap?.call();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.35),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Вырезанная пара маскотов без фона со световой аурой
            Stack(
              alignment: Alignment.center,
              children: [
                // Мягкое радиальное свечение за маскотами
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // Изображение маскотов без фона (PNG RGBA)
                Image.asset(
                  'assets/images/mascots_pair_transparent.png',
                  height: 112,
                  width: 98,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    state.assetFor(),
                    height: 90,
                    width: 90,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 14),

            // 2. Информационный блок маскотов и статус готовности
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Надзаголовок бренда и статусный бейдж
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.6),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              state.localizedBadgeText().toUpperCase(),
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'СААТ-1',
                        style: AppTypography.monoLabel().copyWith(
                          color: AppColors.muted,
                          fontSize: 9,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Название маскотов
                  Text(
                    AppLocaleNotifier.pick(
                      'Барыс & Барыса',
                      'Барыс жана Барыса',
                      'Barys & Barysa',
                    ),
                    style: AppTypography.bodySemibold(palette.fg).copyWith(
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                  ),

                  const SizedBox(height: 3),

                  // Текущее состояние и подсказка от персонажей
                  Text(
                    state.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(palette.secondary).copyWith(
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Интерактивная кнопка перехода к аватару
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocaleNotifier.pick(
                          'Био-аватар и эволюция',
                          'Био-аватар жана өсүү',
                          'Bio-avatar & evolution',
                        ),
                        style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 9,
                        color: AppColors.amber,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
