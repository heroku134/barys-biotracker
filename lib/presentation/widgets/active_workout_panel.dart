import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/workout_session.dart';
import 'glass_card.dart';
import 'run_route_map_widget.dart';

/// Виджет панели активной тренировки (или карточки готовности к старту)
class ActiveWorkoutPanel extends StatelessWidget {
  final SportType selectedSport;
  final bool isWorkoutActive;
  final bool isWorkoutPaused;
  final bool isFinishingWorkout;
  final int elapsedSeconds;
  final int currentBpm;
  final int peakHr;
  final int caloriesBurned;
  final double distanceKm;
  final String currentPaceFormatted;
  final int restSecondsRemaining;
  final List<LatLng> routePoints;
  final LatLng? currentGpsPosition;
  final MapController mapController;
  final UserProfile userProfile;
  final AppLanguage language;
  final VoidCallback onStartWorkout;
  final VoidCallback onTogglePause;
  final VoidCallback onStopWorkout;
  final ValueChanged<int> onStartRestTimer;
  final VoidCallback onCancelRestTimer;

  const ActiveWorkoutPanel({
    super.key,
    required this.selectedSport,
    required this.isWorkoutActive,
    required this.isWorkoutPaused,
    required this.isFinishingWorkout,
    required this.elapsedSeconds,
    required this.currentBpm,
    required this.peakHr,
    required this.caloriesBurned,
    required this.distanceKm,
    required this.currentPaceFormatted,
    required this.restSecondsRemaining,
    required this.routePoints,
    required this.currentGpsPosition,
    required this.mapController,
    required this.userProfile,
    required this.language,
    required this.onStartWorkout,
    required this.onTogglePause,
    required this.onStopWorkout,
    required this.onStartRestTimer,
    required this.onCancelRestTimer,
  });

  static String formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _hrZoneTitle(int bpm, AppLanguage lang) {
    final zoneIndex = userProfile.getHeartRateZone(bpm);
    if (lang == AppLanguage.kyrgyz) {
      switch (zoneIndex) {
        case 0:
          return '1-зона · Жылынуу';
        case 1:
          return '2-зона · Май күйгүзүү';
        case 2:
          return '3-зона · Аэробдук';
        case 3:
          return '4-зона · Босого';
        default:
          return '5-зона · Чок';
      }
    }
    if (lang == AppLanguage.english) {
      switch (zoneIndex) {
        case 0:
          return 'Z1 · Warm Up';
        case 1:
          return 'Z2 · Fat Burn';
        case 2:
          return 'Z3 · Aerobic';
        case 3:
          return 'Z4 · Threshold';
        default:
          return 'Z5 · Peak';
      }
    }
    switch (zoneIndex) {
      case 0:
        return 'З1 · Разминка';
      case 1:
        return 'З2 · Жиросжигание';
      case 2:
        return 'З3 · Аэробная';
      case 3:
        return 'З4 · Порог';
      default:
        return 'З5 · Пик';
    }
  }

  Color _hrZoneColor(int bpm) {
    final zi = userProfile.getHeartRateZone(bpm);
    switch (zi) {
      case 0:
        return const Color(0xFF6B7280);
      case 1:
        return const Color(0xFF10B981);
      case 2:
        return const Color(0xFF3B82F6);
      case 3:
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    selectedSport.icon,
                    color: isWorkoutActive ? AppColors.amber : palette.fg,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectedSport.localizedTitle(language.code),
                    style: TextStyle(color: palette.fg, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              if (isWorkoutActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isWorkoutPaused
                        ? AppColors.amber.withValues(alpha: 0.15)
                        : AppColors.sage.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isWorkoutPaused ? AppColors.amber : AppColors.sage,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isWorkoutPaused ? AppColors.amber : AppColors.sage,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isWorkoutPaused
                            ? AppStrings.tr('sport_paused', language)
                            : AppLocaleNotifier.pick('АКТИВНА', 'АКТИВДҮҮ', 'LIVE'),
                        style: TextStyle(
                          color: isWorkoutPaused ? AppColors.amber : AppColors.sage,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (isWorkoutActive) ...[
            // Интерактивная карта маршрута в реальном времени для уличных видов спорта
            if (selectedSport.needsGps) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.hairline),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      RunRouteMapWidget(
                        points: routePoints,
                        currentPosition: currentGpsPosition,
                        isLive: true,
                        mapController: mapController,
                      ),
                      // GPS статус в углу карты
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: palette.surface.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: palette.hairline),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: currentGpsPosition != null ? AppColors.sage : AppColors.amber,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                currentGpsPosition != null ? 'GPS LIVE' : 'GPS WAIT',
                                style: TextStyle(color: palette.fg, fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Кнопка центрирования
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: InkWell(
                          onTap: () {
                            if (currentGpsPosition != null) {
                              mapController.move(currentGpsPosition!, 16.0);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: palette.surface.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: palette.hairline),
                            ),
                            child: Icon(Icons.my_location, size: 16, color: palette.fg),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Таймер и пульс в крупном размере
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocaleNotifier.pick('ВРЕМЯ СЕССИИ', 'УБАКЫТ', 'SESSION TIME'),
                      style: TextStyle(
                        color: palette.secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatTimer(elapsedSeconds),
                      style: TextStyle(
                        color: palette.fg,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: currentBpm > 0
                            ? AppColors.rose.withValues(alpha: 0.15)
                            : palette.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: currentBpm > 0
                              ? AppColors.rose.withValues(alpha: 0.4)
                              : palette.hairline,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            color: currentBpm > 0 ? AppColors.rose : palette.secondary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currentBpm > 0 ? '$currentBpm bpm' : '-- bpm',
                            style: TextStyle(
                              color: currentBpm > 0 ? AppColors.rose : palette.secondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: currentBpm > 0
                            ? _hrZoneColor(currentBpm).withValues(alpha: 0.15)
                            : palette.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        currentBpm > 0
                            ? _hrZoneTitle(currentBpm, language)
                            : AppLocaleNotifier.pick('Ожидание пульса', 'Пульс күтүлүүдө', 'Waiting for HR'),
                        style: TextStyle(
                          color: currentBpm > 0 ? _hrZoneColor(currentBpm) : palette.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Метрики в реальном времени
            Row(
              children: [
                if (selectedSport.needsGps) ...[
                  _metricBox(palette, AppLocaleNotifier.pick('ДИСТАНЦИЯ', 'АРАЛЫК', 'DISTANCE'), '${distanceKm.toStringAsFixed(2)} км'),
                  const SizedBox(width: 8),
                  _metricBox(palette, AppLocaleNotifier.pick('ТЕМП', 'ТЕМП', 'PACE'), currentPaceFormatted),
                  const SizedBox(width: 8),
                ] else if (selectedSport.hasDistance) ...[
                  _metricBox(palette, AppLocaleNotifier.pick('ДИСТАНЦИЯ', 'АРАЛЫК', 'DISTANCE'), '${distanceKm.toStringAsFixed(2)} км'),
                  const SizedBox(width: 8),
                ],
                _metricBox(palette, AppLocaleNotifier.pick('КАЛОРИИ', 'ККАЛ', 'CALORIES'), '$caloriesBurned'),
                const SizedBox(width: 8),
                _metricBox(palette, AppLocaleNotifier.pick('ПИК HR', 'ПИК HR', 'PEAK HR'), peakHr > 0 ? '$peakHr bpm' : '-- bpm'),
                if (selectedSport.isIndoor) ...[
                  const SizedBox(width: 8),
                  _metricBox(
                    palette,
                    AppLocaleNotifier.pick('ЗОНА', 'ЗОНА', 'ZONE'),
                    currentBpm > 0 ? 'Z${userProfile.getHeartRateZone(currentBpm) + 1}' : 'Z0',
                  ),
                ],
              ],
            ),

            // Таймер отдыха между подходами (для силовых тренировок и зала)
            if (selectedSport.isIndoor) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: restSecondsRemaining > 0 ? AppColors.amber : palette.hairline,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      restSecondsRemaining > 0 ? Icons.timer : Icons.timer_outlined,
                      size: 16,
                      color: restSecondsRemaining > 0 ? AppColors.amber : palette.secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        restSecondsRemaining > 0
                            ? '${AppLocaleNotifier.pick('Отдых', 'Эс алуу', 'Rest')}: ${formatTimer(restSecondsRemaining)}'
                            : AppLocaleNotifier.pick('Отдых между подходами:', 'Эс алуу убактысы:', 'Rest between sets:'),
                        style: TextStyle(
                          color: restSecondsRemaining > 0 ? AppColors.amber : palette.fg,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _restButton('+30с', 30, palette),
                    const SizedBox(width: 6),
                    _restButton('+60с', 60, palette),
                    const SizedBox(width: 6),
                    _restButton('+90с', 90, palette),
                    if (restSecondsRemaining > 0) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: onCancelRestTimer,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          child: Icon(Icons.close, size: 14, color: palette.muted),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Кнопки управления тренировкой
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onTogglePause,
                    icon: Icon(isWorkoutPaused ? Icons.play_arrow : Icons.pause, size: 18),
                    label: Text(isWorkoutPaused ? AppStrings.tr('sport_resume', language) : AppStrings.tr('sport_pause', language)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.fg,
                      side: BorderSide(color: palette.hairline),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isFinishingWorkout ? null : onStopWorkout,
                    icon: isFinishingWorkout
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.stop, size: 18),
                    label: Text(isFinishingWorkout
                        ? AppLocaleNotifier.pick('Сохранение...', 'Сакталууда...', 'Saving...')
                        : AppStrings.tr('sport_finish', language)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.rose,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              AppLocaleNotifier.pick(
                'СААТ-1 синхронизирует живой пульс, каденс и кардио-нагрузку в режиме реального времени.',
                'СААТ-1 реалдуу убакытта пульс, каденс жана жүктөмдү жазат.',
                'SAAT-1 syncs live heart rate, cadence and cardio load in real time.',
              ),
              style: TextStyle(color: palette.secondary, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStartWorkout,
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: Text(
                  '${AppStrings.tr('sport_start', language)} · ${selectedSport.localizedTitle(language.code)}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricBox(KalkanColors palette, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: palette.secondary, fontSize: 8, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(color: palette.fg, fontSize: 12, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _restButton(String label, int seconds, KalkanColors palette) {
    return InkWell(
      onTap: () => onStartRestTimer(seconds),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.hairline),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: palette.fg,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
