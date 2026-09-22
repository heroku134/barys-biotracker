import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';

class KalkanAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool implyLeading;

  const KalkanAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.implyLeading = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 56 : 64);

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    return AppBar(
      backgroundColor: palette.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: implyLeading,
      titleSpacing: implyLeading ? 0 : 20,
      title: subtitle == null
          ? Text(title, style: AppTypography.screenTitle(palette.fg))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.screenTitle(palette.fg)),
                const SizedBox(height: 2),
                Text(subtitle!, style: AppTypography.caption(palette.secondary)),
              ],
            ),
      actions: actions,
    );
  }
}

class KalkanCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const KalkanCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.hairline),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(onTap: onTap, child: box);
  }
}
