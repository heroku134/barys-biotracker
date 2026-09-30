import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';
import '../../core/circa_haptics.dart';
import '../../data/storage/day_journal_repository.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/models/readiness.dart';
import '../../domain/models/workout_session.dart';
import '../widgets/glass_card.dart';
import '../widgets/run_route_map_widget.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  final CompletedWorkout workout;
  final double dayStrainBefore;
  final RecoveryZone recoveryZone;

  const WorkoutSummaryScreen({
    super.key,
    required this.workout,
    required this.dayStrainBefore,
    required this.recoveryZone,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final after = dayStrainBefore + workout.strain;
    final budget = StrainEngine.evaluate(currentStrain: after, recoveryZone: recoveryZone);

    final routePoints = workout.routeCoordinates.map((c) => LatLng(c[0], c[1])).toList();

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.bg,
        elevation: 0,
        title: Text(
          AppLocaleNotifier.pick('Отчёт о тренировке', 'Машыгуунун отчёту', 'Workout Report'),
          style: AppTypography.screenTitle(palette.fg),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share, color: palette.secondary),
            tooltip: AppLocaleNotifier.pick('Поделиться отчетом', 'Бөлүшүү', 'Share Report'),
            onPressed: () {
              CircaHaptics.selectionClick();
              final buffer = StringBuffer();
              buffer.writeln('🛡️ KALKAN SPORT · СААТ-1');
              buffer.writeln('${workout.sport.title} · ${workout.startedAt.day}.${workout.startedAt.month}.${workout.startedAt.year}');
              buffer.writeln('⏱️ Время: ${workout.durationFormatted}');
              if (workout.distanceKm > 0) {
                buffer.writeln('📍 Дистанция: ${workout.distanceKm.toStringAsFixed(2)} км');
                if (workout.avgPaceMinPerKm > 0) {
                  buffer.writeln('⚡ Темп: ${workout.paceFormatted}');
                }
              }
              buffer.writeln('❤️ Пульс ср/макс: ${workout.avgHr} / ${workout.maxHr} bpm');
              buffer.writeln('🔥 Калории: ${workout.calories} ккал');
              if (workout.cadence > 0) {
                buffer.writeln('👟 Шаги / каденс: ${workout.steps} / ${workout.cadence} спм');
              } else if (workout.steps > 0) {
                buffer.writeln('👟 Шаги: ${workout.steps}');
              }
              buffer.writeln('📈 Strain: +${workout.strain.toStringAsFixed(1)}');
              SharePlus.instance.share(ShareParams(text: buffer.toString().trim()));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // 1. Карта маршрута (ТОЛЬКО для уличных видов спорта с реальным GPS-треком)
          if (workout.sport.needsGps && routePoints.isNotEmpty) ...[
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.hairline),
              ),
              child: RunRouteMapWidget(
                points: routePoints,
                isLive: false,
                initialZoom: 14.5,
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 2. Хедер тренировки
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(workout.sport.icon, color: AppColors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text(workout.sport.title, style: AppTypography.bodySemibold(palette.fg)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.sage.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+${workout.strain.toStringAsFixed(1)} STRAIN',
                        style: AppTypography.monoBadge.copyWith(color: AppColors.sage),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _heroStat(palette, AppLocaleNotifier.pick('Время', 'Убакыт', 'Time'), workout.durationFormatted),
                    if (workout.distanceKm > 0)
                      _heroStat(palette, AppLocaleNotifier.pick('Дистанция', 'Аралык', 'Distance'), '${workout.distanceKm.toStringAsFixed(2)} км'),
                    if (workout.distanceKm > 0 && workout.avgPaceMinPerKm > 0)
                      _heroStat(palette, AppLocaleNotifier.pick('Ср. темп', 'Орт. темп', 'Avg. Pace'), workout.paceFormatted),
                    _heroStat(palette, AppLocaleNotifier.pick('Ккал', 'Ккал', 'Calories'), '${workout.calories}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2.1 Информационный баннер внешнего трекера (если импортировано)
          if (workout.isExternal) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: workout.sourceColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: workout.sourceColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: workout.sourceColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(workout.sourceIcon, color: workout.sourceColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${AppLocaleNotifier.pick("Импортировано из", "Импорттолгон булак:", "Imported from")} ${workout.sourceDisplayName}',
                          style: AppTypography.bodySemibold(workout.sourceColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocaleNotifier.pick(
                            'Тренировка записана сторонним сервисом без браслета. Сердечный Strain рассчитан алгоритмом KALKAN и добавлен в суточный баланс.',
                            'Машыгуу тышкы трекерден жүктөлдү. Жүрөк жүктөмү KALKAN алгоритми менен эсептелди.',
                            'Workout imported from external tracker. Cardiovascular Strain calculated by KALKAN engine and added to daily budget.',
                          ),
                          style: AppTypography.caption(palette.fg.withValues(alpha: 0.85)).copyWith(height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 3. Блок данных с часов СААТ-1
          Text(
            workout.isExternal
                ? AppLocaleNotifier.pick('БИОМЕТРИЯ СЕССИИ (${workout.sourceDisplayName.toUpperCase()})', 'МАШЫГУУ БИОМЕТРИЯСЫ', 'SESSION BIOMETRICS')
                : AppLocaleNotifier.pick('БИОМЕТРИЯ С ЧАСОВ СААТ-1', 'СААТ-1 БИОМЕТРИЯСЫ', 'СААТ-1 WATCH BIOMETRICS'),
            style: AppTypography.monoLabel(palette.secondary),
          ),
          const SizedBox(height: 8),

          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _bioTile(palette, Icons.favorite, AppColors.rose, AppLocaleNotifier.pick('Пульс ср.', 'Орт. пульс', 'Avg HR'), '${workout.avgHr} bpm'),
                    const SizedBox(width: 10),
                    _bioTile(palette, Icons.bolt, AppColors.amber, AppLocaleNotifier.pick('Пульс макс.', 'Макс. пульс', 'Max HR'), '${workout.maxHr} bpm'),
                  ],
                ),
                if (!workout.sport.isIndoor || workout.steps > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _bioTile(palette, Icons.directions_walk, AppColors.sage, AppLocaleNotifier.pick('Шаги', 'Кадамдар', 'Steps'), '${workout.steps}'),
                      if (workout.cadence > 0) ...[
                        const SizedBox(width: 10),
                        _bioTile(palette, Icons.speed, const Color(0xFF2563EB), AppLocaleNotifier.pick('Каденс', 'Каденс', 'Cadence'), '${workout.cadence} спм'),
                      ] else ...[
                        const SizedBox(width: 10),
                        _bioTile(palette, Icons.local_fire_department, AppColors.amber, AppLocaleNotifier.pick('Калории', 'Ккал', 'Calories'), '${workout.calories} ккал'),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 14),

                // Пульсовые зоны
                Text(
                  AppLocaleNotifier.pick('Пульсовые зоны интенсивности', 'Жүрөк кагышынын зоналары', 'Heart Rate Intensity Zones'),
                  style: AppTypography.caption(palette.secondary).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _zonesBar(workout.hrZoneSeconds, workout.durationSeconds, isDark),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Суточный бюджет нагрузки
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocaleNotifier.pick('Суточный Strain', 'Күндүк Strain', 'Daily Strain'), style: AppTypography.caption(palette.secondary)),
                    Text(
                      '${dayStrainBefore.toStringAsFixed(1)} → ${after.toStringAsFixed(1)} / 21.0',
                      style: AppTypography.bodyMuted(palette.fg).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (after / 21.0).clamp(0.0, 1.0),
                    backgroundColor: palette.hairline,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.amber),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(budget.budgetStatusText, style: AppTypography.body(palette.fg).copyWith(fontSize: 13, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Кнопки сохранения и выхода
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                CircaHaptics.questCompleted();
                final today = await DayJournalRepository.loadDay(DateTime.now());
                final line = '${workout.sport.title} · ${workout.durationFormatted} · ${workout.distanceKm > 0 ? "${workout.distanceKm.toStringAsFixed(2)} км · " : ""}+${workout.strain.toStringAsFixed(1)} strain';
                await DayJournalRepository.save(DayJournalEntry(
                  dateKey: DayJournalEntry.keyFor(DateTime.now()),
                  sleepHours: today?.sleepHours,
                  sleepNote: today?.sleepNote ?? '',
                  workoutNote: [
                    if (today != null && today.workoutNote.isNotEmpty) today.workoutNote,
                    line,
                  ].join('\n'),
                  note: today?.note ?? '',
                  updatedAt: DateTime.now(),
                ));
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.bookmark_added_outlined, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sage,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              label: Text(
                AppLocaleNotifier.pick('Записать в дневник и закрыть', 'Күндөлүккө жазып жабуу', 'Save to Journal & Close'),
                style: AppTypography.buttonLabel.copyWith(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocaleNotifier.pick('Закрыть без записи', 'Жазуусуз жабуу', 'Close without saving'),
                style: AppTypography.body(palette.secondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(KalkanColors palette, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption(palette.secondary)),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTypography.metric(palette.fg),
          ),
        ],
      ),
    );
  }

  Widget _bioTile(KalkanColors palette, IconData icon, Color color, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.hairline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.monoBadge.copyWith(color: palette.secondary)),
                  const SizedBox(height: 2),
                  Text(value, style: AppTypography.bodySemibold(palette.fg)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zonesBar(List<int> zones, int totalSeconds, bool isDark) {
    final colors = [
      AppColors.sleepBlue,  // Z1 Разминка (#6E86A8)
      AppColors.sage,       // Z2 Жиросжигание (#3D9B74)
      AppColors.strainBlue, // Z3 Аэробная (#3D73C4)
      AppColors.amber,      // Z4 Порог (#C57A2A)
      AppColors.rose,       // Z5 Пик (#C45C5C)
    ];
    final labels = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'];
    final total = totalSeconds > 0 ? totalSeconds : 1;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: List.generate(5, (i) {
              final zSec = (i < zones.length && zones[i] > 0) ? zones[i] : (total * (0.1 + (i == 1 ? 0.3 : 0.15))).toInt();
              final flex = (zSec * 100 ~/ total).clamp(5, 100);
              return Expanded(
                flex: flex,
                child: Container(
                  height: 10,
                  color: colors[i],
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) {
            return Row(
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: colors[i])),
                const SizedBox(width: 4),
                Text(labels[i], style: AppTypography.monoBadge.copyWith(color: colors[i])),
              ],
            );
          }),
        ),
      ],
    );
  }
}

