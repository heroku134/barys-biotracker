import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/circa_haptics.dart';
import '../../domain/models/workout_session.dart';

enum SportCategoryFilter {
  all,
  outdoor,
  indoor,
}

class SportCategoryFilterBar extends StatelessWidget {
  final SportCategoryFilter selectedFilter;
  final ValueChanged<SportCategoryFilter> onFilterChanged;

  const SportCategoryFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);

    return Row(
      children: [
        _chip(SportCategoryFilter.all, AppLocaleNotifier.pick('Все', 'Баары', 'All'), palette),
        const SizedBox(width: 8),
        _chip(SportCategoryFilter.outdoor, AppLocaleNotifier.pick('📍 На улице', '📍 Тышта', '📍 Outdoor'), palette),
        const SizedBox(width: 8),
        _chip(SportCategoryFilter.indoor, AppLocaleNotifier.pick('⚡ В зале / Дома', '⚡ Залда / Үйдө', '⚡ Gym / Home'), palette),
      ],
    );
  }

  Widget _chip(SportCategoryFilter category, String title, KalkanColors palette) {
    final isSelected = selectedFilter == category;
    return InkWell(
      onTap: () {
        KalkanHaptics.selectionClick();
        onFilterChanged(category);
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.amber : palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.amber : palette.hairline,
            width: 1.0,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : palette.fg,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class SportHorizontalCarousel extends StatelessWidget {
  final List<SportType> sports;
  final SportType selectedSport;
  final ValueChanged<SportType> onSportSelected;
  final AppLanguage language;

  const SportHorizontalCarousel({
    super.key,
    required this.sports,
    required this.selectedSport,
    required this.onSportSelected,
    required this.language,
  });

  static String sportSubtitle(SportType sport, AppLanguage lang) {
    switch (sport) {
      case SportType.runOutdoor:
        return AppLocaleNotifier.pick('GPS · темп · каденс', 'GPS · темп', 'GPS · pace');
      case SportType.cycling:
        return AppLocaleNotifier.pick('Скорость · GPS · трек', 'Ылдамдык · GPS', 'Speed · GPS · track');
      case SportType.walkOutdoor:
        return AppLocaleNotifier.pick('Маршрут · шаги · темп', 'Маршрут · кадамдар', 'Route · steps · pace');
      case SportType.strength:
        return AppLocaleNotifier.pick('Пульс · подходы · отдых', 'Пульс · эс алуу', 'Heart rate · sets · rest');
      case SportType.hiit:
        return AppLocaleNotifier.pick('Интервалы · зоны · пик', 'Интервалдар · зоналар', 'Intervals · zones · peak');
      case SportType.combat:
        return AppLocaleNotifier.pick('Выносливость · спарринг', 'Чыдамкайлык · бокс', 'Endurance · sparring');
      case SportType.yoga:
        return AppLocaleNotifier.pick('Восстановление · дыхание', 'Калыбына келүү · дем', 'Recovery · breathwork');
      case SportType.swimming:
        return AppLocaleNotifier.pick('Бассейн · аэробная нагрузка', 'Бассейн · кардио', 'Pool · cardio load');
      case SportType.runIndoor:
        return AppLocaleNotifier.pick('Беговая дорожка · пульс', 'Тренажер · пульс', 'Treadmill · heart rate');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: sports.length,
        separatorBuilder: (_, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final sport = sports[index];
          final isSelected = selectedSport == sport;
          return InkWell(
            onTap: () {
              KalkanHaptics.selectionClick();
              onSportSelected(sport);
            },
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 172,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.amber.withValues(alpha: 0.12) : palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.amber : palette.hairline,
                  width: isSelected ? 1.5 : 1.0,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: AppColors.amber.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
                    : (palette.shadow.a > 0 ? [BoxShadow(color: palette.shadow, blurRadius: 4)] : null),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.amber : palette.raised,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          sport.icon,
                          size: 16,
                          color: isSelected ? Colors.white : palette.secondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (sport.needsGps ? AppColors.sage : AppColors.amber).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sport.needsGps ? 'GPS' : (sport == SportType.strength ? 'СИЛА' : 'ЗАЛ'),
                          style: TextStyle(
                            color: sport.needsGps ? AppColors.sage : AppColors.amber,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sport.localizedTitle(language.code),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.fg,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sportSubtitle(sport, language),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
