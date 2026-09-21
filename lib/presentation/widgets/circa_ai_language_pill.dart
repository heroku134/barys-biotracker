import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/circa_haptics.dart';

/// Овальный AI-переключатель языка («овальный круг снаружи как будто ИИ»)
class CircaAiLanguagePill extends StatelessWidget {
  const CircaAiLanguagePill({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        return GestureDetector(
          onTap: () {
            CircaHaptics.selectionClick();
            AppLocaleNotifier.toggleLanguage();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.22),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: AppColors.amber.withValues(alpha: 0.15),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF38BDF8), Color(0xFFF59E0B)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 9,
                    color: Colors.black,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  language.flag,
                  style: const TextStyle(fontSize: 12),
                ),
                SizedBox(width: 4),
                Text(
                  language.shortTitle,
                  style: TextStyle(
                    color: AppColors.fg,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(width: 5),
                const Icon(
                  Icons.sync_alt,
                  color: AppColors.muted,
                  size: 11,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
