import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barys_biotracker/core/app_language.dart';
import 'package:barys_biotracker/data/ble/ute_ble_bridge.dart';
import 'package:barys_biotracker/domain/intelligence/menstrual_cycle_engine.dart';
import 'package:barys_biotracker/domain/models/telemetry.dart';
import 'package:barys_biotracker/domain/models/user_profile.dart';
import 'package:barys_biotracker/data/storage/user_profile_repository.dart';
import 'package:barys_biotracker/data/storage/partner_cycle_repository.dart';
import 'package:barys_biotracker/domain/models/partner_cycle_data.dart';
import 'package:barys_biotracker/presentation/screens/auth_screen.dart';
import 'package:barys_biotracker/presentation/screens/main_shell.dart';
import 'package:barys_biotracker/presentation/screens/menstrual_cycle_screen.dart';
import 'package:barys_biotracker/presentation/widgets/circa_cycle_card.dart';
import 'package:barys_biotracker/presentation/widgets/circa_partner_cycle_card.dart';
import 'package:barys_biotracker/presentation/widgets/circa_partner_cycle_sheet.dart';

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
    testWidgets('AuthScreen does NOT display gender selector upon login per user requirement', (tester) async {
      final bridge = UteBleBridge();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(bleBridge: bridge),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // User explicitly requested: "зачем выбирать пол при входе в систему не понятно убери"
      expect(find.text('Мужской'), findsNothing);
      expect(find.text('Женский'), findsNothing);
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
      expect(find.text('Овуляция'), findsOneWidget);

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

    test('PartnerCycleData serialization and guidance logic', () {
      final now = DateTime(2026, 9, 20);
      final partner = PartnerCycleData(
        isLinked: true,
        partnerName: 'Айпери',
        partnerCode: 'KLK-CYC-9281',
        cycleDay: 14,
        cycleLength: 28,
        phase: HormonalCyclePhase.ovulatory,
        skinTempDeviation: 0.35,
        energyScore: 5,
        mood: 'Драйв',
        flow: 'none',
        symptoms: ['Энергичность', 'Высокий тонус'],
        note: 'Отличное самочувствие',
        lastSyncTime: now,
      );

      final json = partner.toJson();
      final restored = PartnerCycleData.fromJson(json);

      expect(restored.isLinked, isTrue);
      expect(restored.partnerName, 'Айпери');
      expect(restored.cycleDay, 14);
      expect(restored.currentCycleDay, 14);
      expect(restored.phase, HormonalCyclePhase.ovulatory);
      expect(restored.phaseTitle, 'Овуляция');
      expect(restored.energyLabel, 'Высокий');
      expect(restored.partnerAdvice, contains('Пик энергии'));

      final str = partner.serialize();
      final fromStr = PartnerCycleData.deserialize(str);
      expect(fromStr?.partnerCode, 'KLK-CYC-9281');
    });

    test('PartnerCycleRepository link, unlink and sync flow', () async {
      await PartnerCycleRepository.linkPartner(
        partnerCode: 'KLK-CYC-9281',
        partnerName: 'Айпери',
        cycleDay: 14,
        cycleLength: 28,
      );

      final loaded = await PartnerCycleRepository.loadPartnerCycle();
      expect(loaded.isLinked, isTrue);
      expect(loaded.partnerName, 'Айпери');
      expect(loaded.cycleDay, 14);
      expect(PartnerCycleRepository.notifier.value.isLinked, isTrue);

      // Sync updated day from female profile
      await PartnerCycleRepository.syncFromFemaleProfile(
        const UserProfile(gender: Gender.female, name: 'Айпери', cycleLengthDays: 28),
        currentCycleDay: 15,
        energyScore: 4,
        mood: 'Спокойствие',
        flow: 'none',
        symptoms: ['Ясность'],
        note: 'Спокойный день',
        skinTempDeviation: 0.40,
      );

      final synced = PartnerCycleRepository.notifier.value;
      expect(synced.cycleDay, 15);
      expect(synced.skinTempDeviation, 0.40);
      expect(synced.note, 'Спокойный день');

      // Unlink
      await PartnerCycleRepository.unlinkPartner();
      final unlinked = await PartnerCycleRepository.loadPartnerCycle();
      expect(unlinked.isLinked, isFalse);
    });

    testWidgets('CircaPartnerCycleCard renders on dashboard and opens detail sheet', (tester) async {
      final partnerData = PartnerCycleData(
        isLinked: true,
        partnerName: 'Айпери',
        partnerCode: 'KLK-CYC-9281',
        cycleDay: 14,
        cycleLength: 28,
        phase: HormonalCyclePhase.ovulatory,
        skinTempDeviation: 0.35,
        energyScore: 5,
        mood: 'Драйв',
        symptoms: ['Высокий тонус'],
        lastSyncTime: DateTime.now(),
      );

      bool sheetOpened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => CircaPartnerCycleCard(
                data: partnerData,
                onTap: () {
                  sheetOpened = true;
                  CircaPartnerCycleSheet.show(ctx, partnerData);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify card content
      expect(find.textContaining('БИОРИТМ ПАРТНЁРА'), findsOneWidget);
      expect(find.textContaining('АЙПЕРИ'), findsWidgets);
      expect(find.text('Овуляция'), findsOneWidget);
      expect(find.textContaining('+0.35°C'), findsOneWidget);
      expect(find.textContaining('СААТ-1'), findsWidgets);

      // Tap card to open CircaPartnerCycleSheet
      await tester.tap(find.byType(CircaPartnerCycleCard));
      await tester.pumpAndSettle();

      expect(sheetOpened, isTrue);
      expect(find.textContaining('Биоритм: Айпери'), findsOneWidget);
      expect(find.textContaining('КАК ПОДДЕРЖАТЬ СЕГОДНЯ'), findsOneWidget);
      expect(find.textContaining('°C к норме'), findsOneWidget);
    });

    testWidgets('MenstrualCycleScreen renders fast period button and partner sync card', (tester) async {
      final bridge = UteBleBridge();
      await tester.pumpWidget(
        MaterialApp(
          home: MenstrualCycleScreen(bleBridge: bridge),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Месячные начались сегодня'), findsOneWidget);
      expect(find.textContaining('СИНХРОНИЗАЦИЯ С ПАРТНЁРОМ'), findsOneWidget);
      expect(find.textContaining('ВЫДЕЛЕНИЯ / МЕНСТРУАЦИЯ'), findsOneWidget);
      expect(find.textContaining('СИМПТОМЫ И ОЩУЩЕНИЯ ТЕЛА'), findsOneWidget);
    });
  });
}
