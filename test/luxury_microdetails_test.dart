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

    test('AvatarProfile contains 3 automated sensor quests', () {
      final profile = AvatarManager.getProfile(baseTelemetry, baseline: baseline);
      expect(profile.quests.length, equals(3));

      final strainQuest = profile.quests[0];
      expect(strainQuest.id, equals('quest_strain'));
      expect(strainQuest.title, contains('Дневная норма активности'));
      expect(strainQuest.actionLabel, equals('АВТОМАТИЧЕСКИ'));

      final stepsQuest = profile.quests[1];
      expect(stepsQuest.id, equals('quest_steps'));
      expect(stepsQuest.title, contains('Дневная норма шагов'));
      expect(stepsQuest.actionLabel, equals('АВТОМАТИЧЕСКИ'));

      final sleepQuest = profile.quests[2];
      expect(sleepQuest.id, equals('quest_sleep'));
      expect(sleepQuest.title, contains('Сон и восстановление'));
      expect(sleepQuest.actionLabel, equals('ВЫПОЛНЕНО'));
    });

    test('Quests automatically complete based on telemetry thresholds', () {
      final completedTelemetry = baseTelemetry.copyWith(
        currentDayStrain: 18.0,
        steps: 12000,
        sleepMinutes: 480,
      );
      final profile = AvatarManager.getProfile(completedTelemetry, baseline: baseline);
      expect(profile.quests.every((q) => q.isCompleted), isTrue);
      expect(profile.quests.every((q) => q.actionLabel == 'ВЫПОЛНЕНО'), isTrue);
    });
  });

  group('Luxury Microdetails: BioAvatarScreen Interactive Checklist UI', () {
    late UteBleBridge mockBridge;

    setUp(() {
      mockBridge = UteBleBridge();
    });

    testWidgets('BioAvatarScreen displays checklist and tapping quest shows automated sensor info', (tester) async {
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
      final checklistFinder = find.text('ЕЖЕДНЕВНЫЕ ЗАДАЧИ АКТИВНОСТИ');
      expect(checklistFinder, findsOneWidget);

      // Verify quests rendered
      expect(find.textContaining('Дневная норма активности'), findsOneWidget);
      expect(find.textContaining('Дневная норма шагов'), findsOneWidget);
      expect(find.textContaining('Сон и восстановление'), findsOneWidget);

      // Tapping a quest triggers informative feedback snackbar
      await tester.tap(find.textContaining('Дневная норма шагов'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Шаги учитываются акселерометром СААТ-1'), findsOneWidget);
    });

    testWidgets('Completing all micro-quests displays luxury celebration ritual banner', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      mockBridge.setSimulatedMetrics(strain: 18.0, steps: 11000, sleepMinutes: 480);

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
