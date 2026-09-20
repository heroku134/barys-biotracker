import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barys_biotracker/core/app_colors.dart';
import 'package:barys_biotracker/domain/intelligence/stress_engine.dart';
import 'package:barys_biotracker/presentation/widgets/circa_day_story_dialog.dart';
import 'package:barys_biotracker/presentation/widgets/circa_stress_timeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StressEngine Tests', () {
    test('Strict 3-zone color system (Sage, Amber, Rose)', () {
      expect(StressLevel.rest.color, AppColors.sage);
      expect(StressLevel.low.color, AppColors.sage);
      expect(StressLevel.medium.color, AppColors.amber);
      expect(StressLevel.high.color, AppColors.rose);
    });

    test('Analyze generates 5 structured daily slots with physiological notes and Barys reactions', () {
      final summary = StressEngine.analyze(currentScore: 78);
      expect(summary.currentLevel, StressLevel.high);
      expect(summary.timeline.length, 5);

      final slotIds = summary.timeline.map((s) => s.id).toList();
      expect(slotIds, ['slot_1', 'slot_2', 'slot_3', 'slot_4', 'slot_5']);

      for (final slot in summary.timeline) {
        expect(slot.timeRange.isNotEmpty, isTrue);
        expect(slot.contextTitle.isNotEmpty, isTrue);
        expect(slot.physiologicalNote.isNotEmpty, isTrue);
        expect(slot.barysReaction.isNotEmpty, isTrue);
        expect(slot.barysAsset.isNotEmpty, isTrue);
      }
    });

    test('Custom user tags override default context titles', () {
      final summary = StressEngine.analyze(
        currentScore: 50,
        customTags: {
          'slot_3': '💼 Совет директоров',
        },
      );

      final slot3 = summary.timeline.firstWhere((s) => s.id == 'slot_3');
      expect(slot3.contextTitle, '💼 Совет директоров');
      expect(slot3.userTag, '💼 Совет директоров');
    });

    test('Slot tagging persistence via SharedPreferences', () async {
      await StressEngine.saveSlotTag('slot_3', '⏰ Срочный дедлайн');
      final savedTag = await StressEngine.getSlotTag('slot_3');
      expect(savedTag, '⏰ Срочный дедлайн');
    });
  });

  group('CircaStressTimeline & Story Dialog Widget Tests', () {
    testWidgets('CircaStressTimeline renders story button, slots, and AI predictive card', (tester) async {
      final summary = StressEngine.analyze(currentScore: 72);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CircaStressTimeline(stressSummary: summary),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Заголовок и сводка
      expect(find.text('МОНИТОР СТРЕССА (ВСР + ЧСС)'), findsOneWidget);
      expect(find.text('ВОССТАНОВЛЕНИЕ'), findsOneWidget);
      expect(find.text('ВЫСОКИЙ СТРЕСС'), findsOneWidget);

      // Кнопка каталога дня в 5 событиях
      expect(find.text('ХРОНИКА: ДЕНЬ В 5 СОБЫТИЯХ'), findsOneWidget);
      expect(find.text('Story-просмотр дня с реакциями Барыса'), findsOneWidget);

      // Лента дня
      expect(find.text('ХРОНОЛОГИЯ СТРЕССА СЕГОДНЯ'), findsOneWidget);
      expect(find.text('Тап для разметки'), findsOneWidget);

      // 30-дневная предиктивная карточка
      expect(find.text('ПОВЫШЕННЫЙ КОРТИЗОЛ · 13:30'), findsOneWidget);
      expect(find.text('84% СТРЕСС'), findsOneWidget);
      expect(find.textContaining('протокола и советов'), findsOneWidget);
    });

    testWidgets('Tapping story button launches CircaDayStoryDialog', (tester) async {
      final summary = StressEngine.analyze(currentScore: 72);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CircaStressTimeline(stressSummary: summary),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Нажимаем на кнопку Story-хроники
      await tester.tap(find.text('ХРОНИКА: ДЕНЬ В 5 СОБЫТИЯХ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Проверяем отображение полноэкранной сторис
      expect(find.byType(CircaDayStoryDialog), findsOneWidget);
      expect(find.text('KALKAN СУТОЧНАЯ ХРОНИКА'), findsOneWidget);
      expect(find.text('Событие 1 из 5'), findsOneWidget);
      expect(find.text('БАРЫС-БАТЫР'), findsOneWidget);
      expect(find.text('В сторис'), findsOneWidget);
    });
  });
}
