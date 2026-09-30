import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
export 'kalkan_ui.dart' show KalkanCard;

class KalkanAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool implyLeading;
  final PreferredSizeWidget? bottom;

  const KalkanAppBar({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.leading,
    this.actions,
    this.implyLeading = false,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        (eyebrow != null || subtitle != null ? 64.0 : 56.0) + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final hasEyebrow = eyebrow != null && eyebrow!.isNotEmpty;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return AppBar(
      backgroundColor: palette.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: implyLeading,
      leading: leading,
      titleSpacing: (implyLeading || leading != null) ? 8 : 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasEyebrow) ...[
            Text(
              eyebrow!.toUpperCase(),
              style: AppTypography.monoLabel(palette.secondary).copyWith(
                fontSize: 10,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(title, style: AppTypography.screenTitle(palette.fg)),
          if (hasSubtitle) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppTypography.caption(palette.secondary)),
          ],
        ],
      ),
      actions: actions != null
          ? [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!,
                ),
              ),
            ]
          : null,
      bottom: bottom,
    );
  }
}

