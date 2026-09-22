import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

/// Push-стильная вспышка микро-события выполнения дневного бюджета нагрузки (Strain Milestone)
/// Информирует атлета о прогрессе («78% бюджета взято. Барыс одобряет»)
class CircaStrainMilestoneBadge extends StatefulWidget {
  final double currentStrain;
  final double targetStrainMin;
  final double targetStrainMax;

  const CircaStrainMilestoneBadge({
    super.key,
    required this.currentStrain,
    required this.targetStrainMin,
    required this.targetStrainMax,
  });

  @override
  State<CircaStrainMilestoneBadge> createState() => _CircaStrainMilestoneBadgeState();
}

class _CircaStrainMilestoneBadgeState extends State<CircaStrainMilestoneBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    // Запускаем плавное появление вспышки микро-события
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final target = widget.targetStrainMax > 0 ? widget.targetStrainMax : 14.0;
    final percent = ((widget.currentStrain / target) * 100).round();

    // Показываем событие, если взято хотя бы 35% бюджета
    if (percent < 35) return const SizedBox.shrink();

    final bool isCompleted = percent >= 100;
    final Color badgeColor = isCompleted ? AppColors.sage : AppColors.amber;
    final String message = isCompleted
        ? '100% бюджета закрыто. Батыр доволен!'
        : '$percent% бюджета взято. Барыс одобряет.';

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.raised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.35),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: badgeColor.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badgeColor.withValues(alpha: 0.2),
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.bolt,
                size: 13,
                color: badgeColor,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: AppColors.fg,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                _animController.reverse().then((_) {
                  if (mounted) setState(() => _dismissed = true);
                });
              },
              child: Icon(
                Icons.close,
                size: 14,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
