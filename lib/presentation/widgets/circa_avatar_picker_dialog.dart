import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/circa_haptics.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/models/user_profile.dart';

/// Диалог выбора и загрузки аватара профиля владельца
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.line, width: 1.5)),
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
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ФОТО ПРОФИЛЯ ВЛАДЕЛЬЦА',
                    style: TextStyle(
                      color: AppColors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Выберите фото для отображения в системе',
                    style: TextStyle(
                      color: AppColors.fg,
                      fontSize: 13,
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
          const SizedBox(height: 16),

          // Сетка пресетов
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: presets.length,
            itemBuilder: (ctx, index) {
              final item = presets[index];
              final path = item['path']!;
              final isSelected = profile.avatarPath == path ||
                  (profile.avatarPath == null && index == 0);

              return GestureDetector(
                onTap: () async {
                  CircaHaptics.selectionClick();
                  final updated = profile.copyWith(avatarPath: path);
                  await UserProfileRepository.saveProfile(updated);
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.surface,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppColors.sage),
                        ),
                        content: Text(
                          'Фото владельца «${item['title']}» сохранено',
                          style: const TextStyle(color: AppColors.fg, fontSize: 12),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.amber.withValues(alpha: 0.15)
                        : AppColors.raised,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.amber : AppColors.line,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.amber : AppColors.line,
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            path,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['title']!,
                        style: TextStyle(
                          color: isSelected ? AppColors.amber : AppColors.fg,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Кнопка закрытия
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'ОТМЕНА',
                style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
