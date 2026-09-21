import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

/// Flat precision surface card (Whoop 5.0 / Oura Athletic standard)
/// - Flat dark surface (#0E1015)
/// - 1px hairline border (#1C2029)
/// - Strictly NO shadows, NO blur, NO glassmorphism
class PrecisionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const PrecisionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.borderRadius = 12.0,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? KalkanColors.of(context).surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? KalkanColors.of(context).hairline,
          width: 1.0,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: AppColors.raised.withValues(alpha: 0.4),
        highlightColor: AppColors.raised.withValues(alpha: 0.2),
        child: content,
      );
    }

    return content;
  }
}
