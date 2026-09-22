import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/avatar_image_provider.dart';
import '../../core/circa_haptics.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/models/user_profile.dart';

/// Диалог выбора и загрузки аватара профиля владельца с поддержкой камеры и галереи
class CircaAvatarPickerDialog extends StatelessWidget {
  final UserProfile profile;

  const CircaAvatarPickerDialog({super.key, required this.profile});

  static const List<Map<String, String>> presets = [
    {
      'title': 'Батыр',
      'subtitle': 'Степной воин',
      'path': 'assets/images/warrior_cutout_clean.png',
    },
    {
      'title': 'Атлет',
      'subtitle': 'Спортивная форма',
      'path': 'assets/images/warrior_cutout.png',
    },
    {
      'title': 'Классика',
      'subtitle': 'Минимализм',
      'path': 'assets/images/face_crop.png',
    },
    {
      'title': 'Маскот Барыс',
      'subtitle': 'Снежный барс',
      'path': 'assets/images/hero_barys_normal.jpg',
    },
    {
      'title': 'Бодрый Барыс',
      'subtitle': 'На пике формы',
      'path': 'assets/images/hero_barys_charged.jpg',
    },
  ];

  static void show(BuildContext context, UserProfile profile) {
    CircaHaptics.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => CircaAvatarPickerDialog(profile: profile),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    CircaHaptics.selectionClick();
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );

      if (picked != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await File(picked.path).copy('${appDir.path}/$fileName');

        final updated = profile.copyWith(avatarPath: savedImage.path);
        await UserProfileRepository.saveProfile(updated);

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.surface,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.sage),
              ),
              content: Text(
                'Новое фото профиля успешно сохранено!',
                style: TextStyle(color: AppColors.textNearWhite, fontSize: 12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surface,
            content: Text('Ошибка загрузки фото: $e', style: TextStyle(color: AppColors.rose)),
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
                    'Фото профиля',
                    style: AppTypography.monoLabel().copyWith(
                      color: AppColors.amber,
                      fontSize: 10,
                      letterSpacing: 1.8,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Камера или галерея',
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
          SizedBox(height: 16),

          // 1. Быстрые кнопки камеры и галереи
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(context, ImageSource.camera),
                  icon: Icon(Icons.camera_alt_outlined, color: AppColors.amber, size: 18),
                  label: Text(
                    'Камера',
                    style: AppTypography.monoBadge().copyWith(color: AppColors.textNearWhite),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.raised,
                    side: BorderSide(color: AppColors.hairline),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(context, ImageSource.gallery),
                  icon: Icon(Icons.photo_library_outlined, color: AppColors.sage, size: 18),
                  label: Text(
                    'Галерея',
                    style: AppTypography.monoBadge().copyWith(color: AppColors.textNearWhite),
                  ),
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

          SizedBox(height: 14),

          // Кнопка закрытия
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Отмена',
                style: AppTypography.monoBadge().copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
