import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/circa_haptics.dart';
import '../../data/services/stories_export_service.dart';
import '../../domain/models/readiness.dart';
import '../../domain/models/telemetry.dart';
import 'stories_card_painter.dart';

/// Полноэкранный диалог предпросмотра и экспорта карточки 9:16 в Stories
class StoriesPreviewDialog extends StatefulWidget {
  final BleTelemetry telemetry;
  final ReadinessResult readiness;
  final double currentStrain;
  final String? photoPath;

  const StoriesPreviewDialog({
    super.key,
    required this.telemetry,
    required this.readiness,
    required this.currentStrain,
    this.photoPath,
  });

  static Future<void> show(
    BuildContext context, {
    required BleTelemetry telemetry,
    required ReadinessResult readiness,
    required double currentStrain,
    String? photoPath,
  }) async {
    CircaHaptics.selectionClick();
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => StoriesPreviewDialog(
        telemetry: telemetry,
        readiness: readiness,
        currentStrain: currentStrain,
        photoPath: photoPath,
      ),
    );
  }

  @override
  State<StoriesPreviewDialog> createState() => _StoriesPreviewDialogState();
}

class _StoriesPreviewDialogState extends State<StoriesPreviewDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isExporting = false;

  Future<void> _shareStory() async {
    CircaHaptics.selectionClick();
    setState(() => _isExporting = true);

    final success = await StoriesExportService.captureAndShare(
      boundaryKey: _boundaryKey,
    );

    if (mounted) {
      setState(() => _isExporting = false);
      if (success) {
        CircaHaptics.success();
      }
    }
  }

  Future<void> _saveToDevice() async {
    CircaHaptics.selectionClick();
    setState(() => _isExporting = true);

    final path = await StoriesExportService.captureToFile(
      boundaryKey: _boundaryKey,
    );

    if (mounted) {
      setState(() => _isExporting = false);
      if (path != null) {
        CircaHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surface,
            content: Text('Карточка 1080x1920 сохранена!', style: TextStyle(color: AppColors.sage)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Шапка модала
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ЭКСПОРТ В STORIES (9:16)',
                    style: AppTypography.monoLabel.copyWith(
                      color: AppColors.textNearWhite,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
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
          const SizedBox(height: 10),

          // Карточка 9:16 (масштабируется по доступной высоте экрана)
          Flexible(
            child: Center(
              child: RepaintBoundary(
                key: _boundaryKey,
                child: StoriesCardWidget(
                  telemetry: widget.telemetry,
                  readiness: widget.readiness,
                  currentStrain: widget.currentStrain,
                  photoPath: widget.photoPath,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Кнопки действий
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : _shareStory,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.stage),
                        )
                      : const Icon(Icons.share_outlined, size: 18, color: AppColors.stage),
                  label: Text(
                    _isExporting ? 'РЕНДЕРИНГ...' : 'ПОДЕЛИТЬСЯ (9:16)',
                    style: AppTypography.monoLabel.copyWith(
                      color: AppColors.stage,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.stage,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: _isExporting ? null : _saveToDevice,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.raised,
                    side: const BorderSide(color: AppColors.hairline),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'СОХРАНИТЬ',
                    style: AppTypography.monoBadge.copyWith(
                      color: AppColors.textNearWhite,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
