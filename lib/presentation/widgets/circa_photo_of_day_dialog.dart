import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/circa_haptics.dart';
import '../../domain/models/readiness.dart';
import '../../domain/models/telemetry.dart';
import 'stories_preview_dialog.dart';

/// Диалог выгрузки и создания «Фото Дня» с биометрическим оверлеем (Whoop / Strava athletic style)
class CircaPhotoOfDayDialog extends StatefulWidget {
  final BleTelemetry telemetry;
  final ReadinessResult readiness;
  final double currentStrain;

  const CircaPhotoOfDayDialog({
    super.key,
    required this.telemetry,
    required this.readiness,
    required this.currentStrain,
  });

  static Future<void> show(
    BuildContext context, {
    required BleTelemetry telemetry,
    required ReadinessResult readiness,
    required double currentStrain,
  }) async {
    CircaHaptics.selectionClick();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => CircaPhotoOfDayDialog(
        telemetry: telemetry,
        readiness: readiness,
        currentStrain: currentStrain,
      ),
    );
  }

  @override
  State<CircaPhotoOfDayDialog> createState() => _CircaPhotoOfDayDialogState();
}

class _CircaPhotoOfDayDialogState extends State<CircaPhotoOfDayDialog> {
  String? _photoPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPhoto();
  }

  Future<void> _loadSavedPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getString('kalkan_daily_photo_path');
    if (p != null && File(p).existsSync()) {
      setState(() {
        _photoPath = p;
      });
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    CircaHaptics.selectionClick();
    setState(() => _isLoading = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );

      if (picked != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'daily_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedFile = await File(picked.path).copy('${appDir.path}/$fileName');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('kalkan_daily_photo_path', savedFile.path);

        setState(() {
          _photoPath = savedFile.path;
          _isLoading = false;
        });

        CircaHaptics.success();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surface,
            content: Text('Ошибка при съемке: $e', style: const TextStyle(color: AppColors.rose)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.hairline, width: 1.0)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ручка
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
          SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ФОТО ДНЯ · БИОМЕТРИЯ',
                    style: AppTypography.monoLabel.copyWith(
                      color: AppColors.amber,
                      fontSize: 10,
                      letterSpacing: 1.8,
                    ),
                  ),
                  SizedBox(height: 2),
                  const Text(
                    'Зафиксируйте форму с наложением показателей',
                    style: TextStyle(
                      color: AppColors.textNearWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: AppColors.muted, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          SizedBox(height: 14),

          // Карточка превью фото с биометрическим оверлеем
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.raised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.hairline, width: 1.0),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_photoPath != null)
                  Image.file(
                    File(_photoPath!),
                    fit: BoxFit.cover,
                  )
                else
                  Image.asset(
                    'assets/images/landmarks/ala_too.jpg',
                    fit: BoxFit.cover,
                  ),

                // Затемняющий градиент подложки для читаемости текста
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),

                // Верхний логотип
                Positioned(
                  top: 12,
                  left: 14,
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.sage,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'KALKAN SPORT · СААТ-1',
                        style: AppTypography.monoLabel.copyWith(
                          color: AppColors.textNearWhite,
                          fontSize: 9.5,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Нижний биометрический бейдж (Recovery + Strain + HR)
                Positioned(
                  bottom: 12,
                  left: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.hairline, width: 1.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildOverlayMetric('RECOVERY', '${widget.readiness.score}%', AppColors.sage),
                        Container(width: 1, height: 22, color: AppColors.hairline),
                        _buildOverlayMetric('DAY STRAIN', widget.currentStrain.toStringAsFixed(1), AppColors.amber),
                        Container(width: 1, height: 22, color: AppColors.hairline),
                        _buildOverlayMetric(
                          'HEART RATE',
                          '${widget.telemetry.heartRate > 0 ? widget.telemetry.heartRate : 72} BPM',
                          AppColors.rose,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Кнопки съемки
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, color: AppColors.amber, size: 18),
                  label: Text('СДЕЛАТЬ СНИМОК', style: AppTypography.monoBadge.copyWith(color: AppColors.textNearWhite)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.raised,
                    side: BorderSide(color: AppColors.hairline),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, color: AppColors.sage, size: 18),
                  label: Text('ИЗ ГАЛЕРЕИ', style: AppTypography.monoBadge.copyWith(color: AppColors.textNearWhite)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.raised,
                    side: BorderSide(color: AppColors.hairline),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Кнопка экспорта в Stories (9:16)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                StoriesPreviewDialog.show(
                  context,
                  telemetry: widget.telemetry,
                  readiness: widget.readiness,
                  currentStrain: widget.currentStrain,
                  photoPath: _photoPath,
                );
              },
              icon: const Icon(Icons.auto_awesome_motion_outlined, color: AppColors.amber, size: 18),
              label: Text(
                'ПОДЕЛИТЬСЯ В STORIES (9:16)',
                style: AppTypography.monoLabel.copyWith(
                  color: AppColors.amber,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  fontSize: 11,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.amber, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          SizedBox(height: 10),

          // Кнопка сохранения / закрытия
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                CircaHaptics.success();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.surface,
                    content: Text('Фото дня сохранено в профиле атлета!', style: TextStyle(color: AppColors.sage)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sage,
                foregroundColor: AppColors.stage,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(
                'ГОТОВО',
                style: AppTypography.monoLabel.copyWith(
                  color: AppColors.stage,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayMetric(String label, String value, Color accentColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.monoLabel.copyWith(
            fontSize: 8,
            letterSpacing: 1.0,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.metricValue.copyWith(
            color: accentColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
