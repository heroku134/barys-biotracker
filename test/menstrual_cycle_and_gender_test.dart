import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barys_biotracker/core/app_language.dart';
import 'package:barys_biotracker/data/ble/ute_ble_bridge.dart';
import 'package:barys_biotracker/domain/intelligence/menstrual_cycle_engine.dart';
import 'package:barys_biotracker/domain/models/telemetry.dart';
import 'package:barys_biotracker/domain/models/user_profile.dart';
import 'package:barys_biotracker/data/storage/user_profile_repository.dart';
import 'package:barys_biotracker/presentation/screens/auth_screen.dart';
import 'package:barys_biotracker/presentation/screens/main_shell.dart';
import 'package:barys_biotracker/presentation/screens/menstrual_cycle_screen.dart';
import 'package:barys_biotracker/presentation/widgets/circa_cycle_card.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MenstrualCycleEngine & СААТ-1 Physiological Tests', () {
    test('calculateCurrentCycleDay properly wraps over cycle length', () {
      final now = DateTime.now();
      final day1 = MenstrualCycleEngine.calculateCurrentCycleDay(now, cycleLength: 28);
      expect(day1, 1);

      final day14Ago = now.subtract(const Duration(days: 13));
      final day14 = MenstrualCycleEngine.calculateCurrentCycleDay(day14Ago, cycleLength: 28);
      expect(day14, 14);

      final day29Ago = now.subtract(const Duration(days: 28));
      final wrapped = MenstrualCycleEngine.calculateCurrentCycleDay(day29Ago, cycleLength: 28);
      expect(wrapped, 1);
    });

    test('determinePhase classifies phases accurately across 28 days', () {
      // Days 1..5: Menstrual
      for (int d = 1; d <= 5; d++) {
        expect(MenstrualCycleEngine.determinePhase(d), HormonalCyclePhase.menstrual);
      }

      // Days 6..13: Follicular
      for (int d = 6; d <= 13; d++) {
        expect(MenstrualCycleEngine.determinePhase(d), HormonalCyclePhase.follicular);
      }

      // Days 14..16: Ovulatory
      for (int d = 14; d <= 16; d++) {
        expect(MenstrualCycleEngine.determinePhase(d), HormonalCyclePhase.ovulatory);
      }

      // Days 17..28: Luteal
      for (int d = 17; d <= 28; d++) {
        expect(MenstrualCycleEngine.determinePhase(d), HormonalCyclePhase.luteal);
      }
    });

    test('expectedThermalDelta follows biphasic curve of СААТ-1 sensor', () {
      final tempFollicular = MenstrualCycleEngine.expectedThermalDelta(8);
      final tempOvulatory = MenstrualCycleEngine.expectedThermalDelta(14);
      final tempLuteal = MenstrualCycleEngine.expectedThermalDelta(21);

      // Follicular is cooler than baseline
      expect(tempFollicular, lessThan(0.0));
      // Ovulatory starts thermal shift
      expect(tempOvulatory, greaterThan(0.0));
      // Luteal is elevated due to progesterone
      expect(tempLuteal, greaterThan(0.3));
    });

    test('analyze adjusts Strain budget dynamically for СААТ-1', () {
      final telemetry = BleTelemetry(
        timestamp: DateTime.now(),
        skinTempDeviation: 0.38,
      );

      // 1. Follicular phase (Day 10)
      final profileFollicular = const UserProfile(
        gender: Gender.female,
        cycleDay: 10,
        cycleLengthDays: 28,
      );
      final resFollicular = MenstrualCycleEngine.analyze(
        telemetry: telemetry,
        profile: profileFollicular,
        language: AppLanguage.russian,
      );
      expect(resFollicular.phase, HormonalCyclePhase.follicular);
      expect(resFollicular.targetStrainMax, greaterThanOrEqualTo(16.0));

      // 2. Luteal phase (Day 22)
      final profileLuteal = const UserProfile(
        gender: Gender.female,
        cycleDay: 22,
        cycleLengthDays: 28,
      );
      final resLuteal = MenstrualCycleEngine.analyze(
        telemetry: telemetry,
        profile: profileLuteal,
        language: AppLanguage.russian,
      );
      expect(resLuteal.phase, HormonalCyclePhase.luteal);
      // Strain is softened to protect CNS
      expect(resLuteal.targetStrainMax, lessThanOrEqualTo(12.0));
    });

    test('UserProfile JSON serialization preserves cycle fields', () {
      final date = DateTime(2026, 9, 1);
      final profile = UserProfile(
        name: 'Айпери',
        gender: Gender.female,
        cycleDay: 15,
        cycleLengthDays: 30,
        periodDurationDays: 6,
        lastPeriodStartDate: date,
      );

      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.name, 'Айпери');
      expect(restored.gender, Gender.female);
      expect(restored.cycleDay, 15);
      expect(restored.cycleLengthDays, 30);
      expect(restored.periodDurationDays, 6);
      expect(restored.lastPeriodStartDate, date);
    });
  });

  group('UI Tests: AuthScreen Gender Selector & CircaCycleCard', () {
    testWidgets('AuthScreen displays male and female gender options', (tester) async {
      final bridge = UteBleBridge();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(bleBridge: bridge),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify gender options exist
      expect(find.text('Мужской'), findsOneWidget);
      expect(find.text('Женский'), findsOneWidget);

      // Tap female option
      await tester.tap(find.text('Женский'));
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('CircaCycleCard renders day, phase, and СААТ-1 temperature', (tester) async {
      final telemetry = BleTelemetry(
        timestamp: DateTime.now(),
        skinTempDeviation: 0.32,
      );
      final profile = const UserProfile(
        gender: Gender.female,
        cycleDay: 14,
        cycleLengthDays: 28,
      );

      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircaCycleCard(
              telemetry: telemetry,
              profile: profile,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('14'), findsOneWidget);
      expect(find.textContaining('СААТ-1'), findsWidgets);
      expect(find.textContaining('+0.32°C'), findsOneWidget);

      await tester.tap(find.byType(CircaCycleCard));
      expect(tapped, isTrue);
    });

    testWidgets('MenstrualCycleScreen renders 28-day orbit and pillars', (tester) async {
      final bridge = UteBleBridge();
      await tester.pumpWidget(
        MaterialApp(
          home: MenstrualCycleScreen(bleBridge: bridge),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('СААТ-1'), findsWidgets);
      expect(find.textContaining('ТЕРМОСЕНСОР'), findsWidgets);
      expect(find.textContaining('ЖУРНАЛ САМОЧУВСТВИЯ'), findsOneWidget);
    });

    testWidgets('MainShell adapts 4th tab based on user gender', (tester) async {
      final bridge = UteBleBridge();

      // Set profile as female
      await UserProfileRepository.saveProfile(
        const UserProfile(gender: Gender.female, name: 'Айпери'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MainShell(bleBridge: bridge),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Female sees 'Цикл' in navbar
      expect(find.text('Цикл'), findsOneWidget);
      expect(find.text('Спорт'), findsNothing);

      // Change profile to male
      await UserProfileRepository.saveProfile(
        const UserProfile(gender: Gender.male, name: 'Алихан'),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Male sees 'Спорт' in navbar
      expect(find.text('Спорт'), findsOneWidget);
      expect(find.text('Цикл'), findsNothing);
    });
  });
}
