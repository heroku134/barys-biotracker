import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';

/// Shared visual primitives for the KALKAN athletic interface.
/// Keep product UI quiet, measurable and useful: no decorative glow or glass.
class KalkanUi {
  static const double pageHorizontal = 20;
  static const double pagePadding = 20;
  static const double cardStackSpacing = 12;
  static const double cardPadding = 16;
  static const double cardRadius = 14;
  static const double controlRadius = 8;
  static const double progressRadius = 4;
  static const double minTapTarget = 44;
  static const double hairline = 1.0;
}

/// Canonical athletic card surface for KALKAN SPORT.
/// - Flat surface (#0E1015 Obsidian in dark / #FFFFFF Porcelain in light)
/// - 1px hairline border (#1C2029 / #E2E2DE)
/// - Strictly NO blur, NO glassmorphism, NO decorative neon glow
/// - In dark mode: completely flat (0 shadow)
/// - In light mode: quiet soft elevation shadow
class KalkanCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final double? width;

  const KalkanCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KalkanUi.cardPadding),
    this.margin,
    this.borderRadius = KalkanUi.cardRadius,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final content = Container(
      width: width,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? palette.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? palette.hairline, width: KalkanUi.hairline),
        boxShadow: palette.shadow.a == 0
            ? null
            : [BoxShadow(color: palette.shadow, blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: child,
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

/// Backwards compatibility alias
typedef KalkanSurface = KalkanCard;

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
        borderRadius: BorderRadius.circular(KalkanUi.cardRadius),
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
