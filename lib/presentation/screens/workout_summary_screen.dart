import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';
import '../../data/storage/day_journal_repository.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/models/readiness.dart';
import '../../domain/models/workout_session.dart';

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
    final ru = AppLocaleNotifier.current != AppLanguage.kyrgyz;
    final after = dayStrainBefore + workout.strain;
    final budget = StrainEngine.evaluate(currentStrain: after, recoveryZone: recoveryZone);

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.bg,
        title: Text(ru ? 'Сессия закрыта' : 'Машыгуу бүттү', style: AppTypography.screenTitle(palette.fg)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(workout.sport.title, style: AppTypography.bodySemibold(palette.fg)),
          const SizedBox(height: 4),
          Text(workout.durationFormatted, style: AppTypography.caption(palette.secondary)),
          const SizedBox(height: 16),
          Row(children: [
            _tile(palette, ru ? 'Strain сессии' : 'Сессия strain', '+${workout.strain.toStringAsFixed(1)}'),
            const SizedBox(width: 8),
            _tile(palette, ru ? 'День' : 'Күн', '${dayStrainBefore.toStringAsFixed(1)} → ${after.toStringAsFixed(1)}'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _tile(palette, ru ? 'Пульс ср.' : 'Орт. пульс', '${workout.avgHr}'),
            const SizedBox(width: 8),
            _tile(palette, ru ? 'Ккал' : 'Ккал', '${workout.calories}'),
          ]),
          const SizedBox(height: 16),
          Text(budget.budgetStatusText, style: AppTypography.body(palette.fg).copyWith(height: 1.4)),
          const SizedBox(height: 8),
          Text(
            ru
                ? 'Цель дня ${budget.targetStrainMin.toStringAsFixed(0)}–${budget.targetStrainMax.toStringAsFixed(1)}'
                : 'Күндүк максат ${budget.targetStrainMin.toStringAsFixed(0)}–${budget.targetStrainMax.toStringAsFixed(1)}',
            style: AppTypography.caption(palette.secondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              final today = await DayJournalRepository.loadDay(DateTime.now());
              final line = '${workout.sport.title} · ${workout.durationFormatted} · +${workout.strain.toStringAsFixed(1)} strain';
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white, elevation: 0),
            child: Text(ru ? 'В дневник и закрыть' : 'Күндөлүккө жазуу'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(ru ? 'Закрыть' : 'Жабуу', style: TextStyle(color: palette.secondary)),
          ),
        ],
      ),
    );
  }

  Widget _tile(KalkanColors palette, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: palette.hairline)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTypography.caption(palette.secondary)),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.metricValue(palette.fg)),
        ]),
      ),
    );
  }
}
