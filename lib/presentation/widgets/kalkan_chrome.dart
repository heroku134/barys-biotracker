import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
export 'kalkan_ui.dart' show KalkanCard;

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

