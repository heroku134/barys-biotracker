import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/intelligence/readiness_engine.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/telemetry.dart';
import 'circa_share_card_widget.dart';

class CircaShareSheet extends StatefulWidget {
  final BleTelemetry telemetry;
  final PersonalBaseline baseline;
  final String userName;

  const CircaShareSheet({
    super.key,
    required this.telemetry,
    required this.baseline,
    this.userName = 'Данияр',
  });

  static void show(
    BuildContext context, {
    required BleTelemetry telemetry,
    required PersonalBaseline baseline,
    String userName = 'Данияр',
  }) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CircaShareSheet(
        telemetry: telemetry,
        baseline: baseline,
        userName: userName,
      ),
    );
  }

  @override
  State<CircaShareSheet> createState() => _CircaShareSheetState();
}

class _CircaShareSheetState extends State<CircaShareSheet> {
  ShareCardTheme _selectedTheme = ShareCardTheme.recovery;
  final GlobalKey _cardKey = GlobalKey();
  bool _isExporting = false;

  void _handleShare(String actionTitle) {
    HapticFeedback.heavyImpact();
    setState(() => _isExporting = true);

    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.sage, width: 1.0),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.sage, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$actionTitle: карточка 9:16 готова к публикации',
                    style: const TextStyle(
                      color: AppColors.fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final readiness = ReadinessEngine.calculate(widget.telemetry, baseline: widget.baseline);
    final avatarProfile = AvatarManager.getProfile(widget.telemetry, baseline: widget.baseline);
    final strainResult = StrainEngine.evaluate(
      currentStrain: widget.telemetry.currentDayStrain,
      recoveryZone: readiness.zone,
      zoneMinutes: widget.telemetry.zoneMinutes,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.stage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.line, width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ручка шторки
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.faint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Заголовок шторки
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'СТАТУСНАЯ КАРТОЧКА (PROOF OF FORM)',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Швейцарский стиль · Формат 9:16 Stories',
                      style: TextStyle(
                        color: AppColors.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.muted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Переключатель тем карточки
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: ShareCardTheme.values.map((theme) {
                  final isSelected = _selectedTheme == theme;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTheme = theme);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.raised : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.line : Colors.transparent,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            theme.label,
                            style: TextStyle(
                              color: isSelected ? AppColors.fg : AppColors.muted,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Превью карточки 9:16 с масштабированием
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.52,
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: CircaShareCardWidget(
                      theme: _selectedTheme,
                      telemetry: widget.telemetry,
                      baseline: widget.baseline,
                      readiness: readiness,
                      avatarProfile: avatarProfile,
                      strainResult: strainResult,
                      userName: widget.userName,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Кнопки действий
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: AppColors.stage,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isExporting
                        ? null
                        : () => _handleShare('Поделиться'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isExporting)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(AppColors.stage),
                            ),
                          )
                        else ...[
                          const Icon(Icons.ios_share, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'ПОДЕЛИТЬСЯ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.fg,
                      side: const BorderSide(color: AppColors.line, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isExporting
                        ? null
                        : () => _handleShare('Сохранено в галерею'),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download, size: 18, color: AppColors.muted),
                        SizedBox(width: 4),
                        Text(
                          'PNG',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
