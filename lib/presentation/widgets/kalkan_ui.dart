import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';

/// Shared visual primitives for the KALKAN athletic interface.
/// Keep product UI quiet, measurable and useful: no decorative glow or glass.
class KalkanUi {
  static const double pageHorizontal = 20;
  static const double cardRadius = 12;
  static const double controlRadius = 8;
  static const double hairline = 1;
}

class KalkanSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  const KalkanSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = KalkanUi.cardRadius,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? AppColors.hairline),
    );
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: ShapeDecoration(
        color: color ?? AppColors.surface,
        shape: shape,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        overlayColor: WidgetStatePropertyAll(AppColors.raised.withValues(alpha: 0.55)),
        child: content,
      ),
    );
  }
}

class KalkanSectionLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const KalkanSectionLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTypography.monoLabel.copyWith(color: color ?? AppColors.textSecondary),
      );
}

class KalkanPageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget? trailing;

  const KalkanPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KalkanUi.pageHorizontal, 18, KalkanUi.pageHorizontal, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KalkanSectionLabel(eyebrow),
                const SizedBox(height: 5),
                Text(title, style: AppTypography.screenTitle),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class KalkanStatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const KalkanStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(label, style: AppTypography.monoBadge.copyWith(color: color)),
        ],
      ),
    );
  }
}

class KalkanMark extends StatelessWidget {
  final double size;

  const KalkanMark({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.amber, width: 2),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Text(
        'K',
        style: AppTypography.heroNumber.copyWith(
          color: AppColors.amber,
          fontSize: size * 0.48,
          letterSpacing: -2,
        ),
      ),
    );
  }
}
