import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'kalkan_ui.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KalkanUi.cardPadding),
    this.margin,
    this.borderRadius = KalkanUi.cardRadius,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? palette.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? palette.hairline, width: 1.0),
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
