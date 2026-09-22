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
              final text = '''
🛡️ KALKAN SPORT · СААТ-1
${workout.sport.title} · ${workout.startedAt.day}.${workout.startedAt.month}.${workout.startedAt.year}
⏱️ Время: ${workout.durationFormatted}
📍 Дистанция: ${workout.distanceKm.toStringAsFixed(2)} км
⚡ Темп: ${workout.paceFormatted}
❤️ Пульс ср/макс: ${workout.avgHr} / ${workout.maxHr} bpm
🔥 Калории: ${workout.calories} ккал
👟 Шаги / каденс: ${workout.steps} / ${workout.cadence} спм
📈 Strain: +${workout.strain.toStringAsFixed(1)}
''';
              SharePlus.instance.share(ShareParams(text: text.trim()));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // 1. Карта маршрута (если есть координаты пробежки)
          if (routePoints.length >= 2) ...[
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
                        style: const TextStyle(color: AppColors.sage, fontSize: 11, fontWeight: FontWeight.w700),
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
                    if (workout.distanceKm > 0)
                      _heroStat(palette, AppLocaleNotifier.pick('Ср. темп', 'Орт. темп', 'Avg. Pace'), workout.paceFormatted),
                    _heroStat(palette, AppLocaleNotifier.pick('Ккал', 'Ккал', 'Calories'), '${workout.calories}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Блок данных с часов СААТ-1
          Text(
            AppLocaleNotifier.pick('БИОМЕТРИЯ С ЧАСОВ СААТ-1', 'СААТ-1 БИОМЕТРИЯСЫ', 'СААТ-1 WATCH BIOMETRICS'),
            style: TextStyle(
              color: palette.secondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    _bioTile(palette, Icons.directions_walk, AppColors.sage, AppLocaleNotifier.pick('Шаги', 'Кадамдар', 'Steps'), '${workout.steps > 0 ? workout.steps : (workout.durationSeconds * 2.5).toInt()}'),
                    const SizedBox(width: 10),
                    _bioTile(palette, Icons.speed, const Color(0xFF2563EB), AppLocaleNotifier.pick('Каденс', 'Каденс', 'Cadence'), '${workout.cadence > 0 ? workout.cadence : 162} спм'),
                  ],
                ),
                const SizedBox(height: 14),

                // Пульсовые зоны
                Text(
                  AppLocaleNotifier.pick('Пульсовые зоны интенсивности', 'Жүрөк кагышынын зоналары', 'Heart Rate Intensity Zones'),
                  style: TextStyle(color: palette.secondary, fontSize: 11, fontWeight: FontWeight.w600),
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
                      style: TextStyle(color: palette.fg, fontWeight: FontWeight.w700, fontSize: 12),
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
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocaleNotifier.pick('Закрыть без записи', 'Жазуусуз жабуу', 'Close without saving'),
                style: TextStyle(color: palette.secondary),
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
          Text(label, style: TextStyle(color: palette.secondary, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(color: palette.fg, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3),
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
                  Text(label, style: TextStyle(color: palette.secondary, fontSize: 9, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(color: palette.fg, fontSize: 13, fontWeight: FontWeight.w700)),
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
      const Color(0xFF6B7280), // Z1 Разминка
      const Color(0xFF10B981), // Z2 Жиросжигание
      const Color(0xFF3B82F6), // Z3 Аэробная
      const Color(0xFFF59E0B), // Z4 Порог
      const Color(0xFFEF4444), // Z5 Пик
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
                Text(labels[i], style: TextStyle(color: colors[i], fontSize: 9, fontWeight: FontWeight.w700)),
              ],
            );
          }),
        ),
      ],
    );
  }
}
