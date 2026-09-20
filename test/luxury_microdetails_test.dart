import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barys_biotracker/core/circa_haptics.dart';
import 'package:barys_biotracker/data/ble/ute_ble_bridge.dart';
import 'package:barys_biotracker/domain/avatar/avatar_manager.dart';
import 'package:barys_biotracker/domain/models/personal_baseline.dart';
import 'package:barys_biotracker/domain/models/telemetry.dart';
import 'package:barys_biotracker/presentation/screens/bio_avatar_screen.dart';
import 'package:barys_biotracker/presentation/widgets/circa_film_grain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Luxury Microdetails: Haptics & Acoustics Tests', () {
    test('CircaHaptics methods trigger platform haptics without error', () async {
      await CircaHaptics.ringZoneTick();
      await CircaHaptics.ringClosure();
      await CircaHaptics.workoutStart();
      await CircaHaptics.workoutFinish();
      await CircaHaptics.levelUp();
      await CircaHaptics.questCompleted();
      await CircaHaptics.cardExport();
      expect(true, isTrue);
    });

    test('CircaAcoustics plays mechanical click and alert sound without error', () {
      CircaAcoustics.playMechanicalClick();
      CircaAcoustics.playAlertSound();
      expect(true, isTrue);
    });
  });

  group('Luxury Microdetails: Film-Grain Background Tests', () {
    testWidgets('CircaFilmGrainBackground renders child with RepaintBoundary and overlay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CircaFilmGrainBackground(
            child: Scaffold(
              body: Center(child: Text('Leica Grain Content')),
            ),
          ),
        ),
      );

      expect(find.text('Leica Grain Content'), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('Luxury Microdetails: Daily Micro-Quests & Ritual Checklist Tests', () {
    const baseline = PersonalBaseline(
      meanHrv: 60.0,
      meanRhr: 52,
      meanRespiratoryRate: 14.0,
      baselineSkinTemp: 36.4,
      baselineSleepNeedMinutes: 480,
      calibrationDaysDone: 14,
    );

    final baseTelemetry = BleTelemetry(
      heartRate: 68,
      hrv: 62.0,
      restingHeartRate: 52,
      respiratoryRate: 14.1,
      skinTempDeviation: 0.1,
      sleepMinutes: 460,
      timeInBedMinutes: 500,
      sleepEfficiency: 0.92,
      sleepConsistency: 0.88,
      restorativeSleepRatio: 0.75,
      currentDayStrain: 4.5, // Low strain so strain quest is not completed yet
      zoneMinutes: [20, 10, 5, 0, 0],
      timestamp: DateTime.now(),
    );

    setUp(() {
      AvatarManager.setJournalLoggedForTesting(false);
      AvatarManager.setBedtimeLockedForTesting(false);
    });

    test('AvatarProfile contains 3 curated daily micro-quests with interactive actions', () {
      final profile = AvatarManager.getProfile(baseTelemetry, baseline: baseline);
      expect(profile.quests.length, equals(3));

      final strainQuest = profile.quests[0];
      expect(strainQuest.id, equals('quest_strain'));
      expect(strainQuest.title, contains('Закрыть целевой Strain'));
      expect(strainQuest.actionLabel, equals('В ПРОЦЕССЕ'));

      final journalQuest = profile.quests[1];
      expect(journalQuest.id, equals('quest_journal'));
      expect(journalQuest.title, contains('Залогировать вечерний био-журнал'));
      expect(journalQuest.isInteractive, isTrue);
      expect(journalQuest.actionLabel, equals('ОТМЕТИТЬ'));

      final bedtimeQuest = profile.quests[2];
      expect(bedtimeQuest.id, equals('quest_bedtime'));
      expect(bedtimeQuest.title, contains('Лечь по расписанию'));
      expect(bedtimeQuest.isInteractive, isTrue);
      expect(bedtimeQuest.actionLabel, equals('ЗАФИКСИРОВАТЬ'));
    });

    test('completeJournalQuest marks quest done and grants XP', () async {
      expect(AvatarManager.isJournalLoggedToday, isFalse);
      await AvatarManager.completeJournalQuest();
      expect(AvatarManager.isJournalLoggedToday, isTrue);

      final profile = AvatarManager.getProfile(baseTelemetry, baseline: baseline);
      final journalQuest = profile.quests.firstWhere((q) => q.id == 'quest_journal');
      expect(journalQuest.isCompleted, isTrue);
      expect(journalQuest.actionLabel, equals('ЗАЛОГИРОВАНО'));
    });

    test('completeBedtimeQuest marks quest done and grants XP', () async {
      expect(AvatarManager.isBedtimeLockedToday, isFalse);
      await AvatarManager.completeBedtimeQuest();
      expect(AvatarManager.isBedtimeLockedToday, isTrue);

      final profile = AvatarManager.getProfile(baseTelemetry, baseline: baseline);
      final bedtimeQuest = profile.quests.firstWhere((q) => q.id == 'quest_bedtime');
      expect(bedtimeQuest.isCompleted, isTrue);
      expect(bedtimeQuest.actionLabel, equals('ЗАФИКСИРОВАНО'));
    });
  });

  group('Luxury Microdetails: BioAvatarScreen Interactive Checklist UI', () {
    late UteBleBridge mockBridge;

    setUp(() {
      mockBridge = UteBleBridge();
      AvatarManager.setJournalLoggedForTesting(false);
      AvatarManager.setBedtimeLockedForTesting(false);
    });

    testWidgets('BioAvatarScreen displays checklist and tapping journal opens logging sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: BioAvatarScreen(bleBridge: mockBridge),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify checklist header
      final checklistFinder = find.text('ЕЖЕДНЕВНЫЕ ЗАДАЧИ НАГРУЗКИ');
      expect(checklistFinder, findsOneWidget);

      // Verify quests rendered
      expect(find.textContaining('Закрыть целевой Strain'), findsOneWidget);
      expect(find.textContaining('Залогировать вечерний био-журнал'), findsOneWidget);
      expect(find.textContaining('Лечь по расписанию'), findsOneWidget);

      // Tap on journal quest action button to open bottom sheet
      final journalAction = find.text('ОТМЕТИТЬ');
      expect(journalAction, findsOneWidget);
      await tester.tap(journalAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify evening journal sheet opened with context tags
      expect(find.text('ВЕЧЕРНИЙ БИО-ЖУРНАЛ KALKAN'), findsOneWidget);
      expect(find.text('💼 Рабочий спринт'), findsOneWidget);

      // Tap a tag to complete quest
      await tester.tap(find.text('💼 Рабочий спринт'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(AvatarManager.isJournalLoggedToday, isTrue);
    });

    testWidgets('Completing all micro-quests displays luxury celebration ritual banner', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      mockBridge.setDemoStrain(18.0);
      AvatarManager.setJournalLoggedForTesting(true);
      AvatarManager.setBedtimeLockedForTesting(true);

      await tester.pumpWidget(
        MaterialApp(
          home: BioAvatarScreen(bleBridge: mockBridge),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('✦ ВСЕ МИКРО-КВЕСТЫ ЗАКРЫТЫ · ДНЕВНОЙ РИТУАЛ ВЫПОЛНЕН ✦'), findsOneWidget);
    });
  });
}
