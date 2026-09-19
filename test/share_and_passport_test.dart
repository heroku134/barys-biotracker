import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barys_biotracker/data/ble/ute_ble_bridge.dart';
import 'package:barys_biotracker/domain/avatar/avatar_manager.dart';
import 'package:barys_biotracker/domain/intelligence/readiness_engine.dart';
import 'package:barys_biotracker/domain/intelligence/strain_engine.dart';
import 'package:barys_biotracker/domain/models/personal_baseline.dart';
import 'package:barys_biotracker/domain/models/telemetry.dart';
import 'package:barys_biotracker/presentation/screens/profile_screen.dart';
import 'package:barys_biotracker/presentation/widgets/circa_share_card_widget.dart';
import 'package:barys_biotracker/presentation/widgets/circa_share_sheet.dart';

void main() {
  group('Share Cards & Gold Edition Tests', () {
    const baseline = PersonalBaseline(
      meanHrv: 60.0,
      meanRhr: 52,
      meanRespiratoryRate: 14.0,
      baselineSkinTemp: 36.4,
      baselineSleepNeedMinutes: 480,
      calibrationDaysDone: 14,
    );

    final standardTelemetry = BleTelemetry(
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
      currentDayStrain: 11.4,
      zoneMinutes: [40, 30, 20, 10, 5],
      timestamp: DateTime.now(),
    );

    // Золотая готовность (ЧСС покоя ниже базы, высокая ВСР, идеальный сон)
    final goldTelemetry = BleTelemetry(
      heartRate: 54,
      hrv: 85.0,
      restingHeartRate: 46,
      respiratoryRate: 13.5,
      skinTempDeviation: 0.0,
      sleepMinutes: 510,
      timeInBedMinutes: 530,
      sleepEfficiency: 0.96,
      sleepConsistency: 0.95,
      restorativeSleepRatio: 0.88,
      currentDayStrain: 15.0,
      zoneMinutes: [50, 40, 30, 15, 10],
      timestamp: DateTime.now(),
    );

    testWidgets('CircaShareCardWidget displays serial number and standard layout', (tester) async {
      final readiness = ReadinessEngine.calculate(standardTelemetry, baseline: baseline);
      final avatar = AvatarManager.getProfile(standardTelemetry, baseline: baseline);
      final strain = StrainEngine.evaluate(
        currentStrain: standardTelemetry.currentDayStrain,
        recoveryZone: readiness.zone,
        zoneMinutes: standardTelemetry.zoneMinutes,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircaShareCardWidget(
                theme: ShareCardTheme.recovery,
                telemetry: standardTelemetry,
                baseline: baseline,
                readiness: readiness,
                avatarProfile: avatar,
                strainResult: strain,
              ),
            ),
          ),
        ),
      );

      expect(find.text('RECOVERY №048 / 2026'), findsOneWidget);
      expect(find.text('${readiness.score}'), findsOneWidget);
      expect(find.text('CIRCA ONE · ALMATY · 2026'), findsOneWidget);
      expect(find.text('AUTONOMIC RECOVERY INDEX'), findsOneWidget);
      expect(find.text('GOLD EMBOSS'), findsNothing);
    });

    testWidgets('CircaShareCardWidget triggers Rare Gold Edition when Recovery >= 95 or synced high strain', (tester) async {
      final goldReadiness = ReadinessEngine.calculate(goldTelemetry, baseline: baseline);
      final avatar = AvatarManager.getProfile(goldTelemetry, baseline: baseline);
      final strain = StrainEngine.evaluate(
        currentStrain: goldTelemetry.currentDayStrain,
        recoveryZone: goldReadiness.zone,
        zoneMinutes: goldTelemetry.zoneMinutes,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircaShareCardWidget(
                theme: ShareCardTheme.recovery,
                telemetry: goldTelemetry,
                baseline: baseline,
                readiness: goldReadiness,
                avatarProfile: avatar,
                strainResult: strain,
              ),
            ),
          ),
        ),
      );

      // Проверка ювелирного золотого издания
      expect(find.text('RECOVERY №007 / 2026'), findsOneWidget);
      expect(find.text('${goldReadiness.score}'), findsOneWidget);
      expect(find.text('EDITION PRIVÉE'), findsOneWidget);
      expect(find.text('GOLD EMBOSS'), findsOneWidget);
      expect(find.text('GOLD PROOF OF FORM · CERTIFIED'), findsOneWidget);
    });

    testWidgets('CircaShareSheet renders format toggle (PNG vs 5s Stories)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircaShareSheet(
              telemetry: standardTelemetry,
              baseline: baseline,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('СТАТИЧНЫЙ PNG'), findsOneWidget);
      expect(find.text('ЖИВАЯ СТОРИС (5 СЕК)'), findsOneWidget);
      expect(find.text('ПОДЕЛИТЬСЯ'), findsOneWidget);
      expect(find.text('PNG'), findsOneWidget);

      // Переключаем формат на живую сторис
      await tester.tap(find.text('ЖИВАЯ СТОРИС (5 СЕК)'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ЭКСПОРТ СТОРИС 5s'), findsOneWidget);
      expect(find.text('MP4'), findsOneWidget);
    });
  });

  group('Biometric Passport & Crisis Mode Tests', () {
    late UteBleBridge bleBridge;

    setUp(() {
      bleBridge = UteBleBridge();
    });

    tearDown(() {
      bleBridge.dispose();
    });

    testWidgets('ProfileScreen renders Biometric Passport artifact and MRZ zone', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(bleBridge: bleBridge),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('РЕСПУБЛИКА КАЗАХСТАН · РЕГИСТР БИОМЕТРИИ'), findsOneWidget);
      expect(find.text('CIRCA ID-KZ · № 784-092/26'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('АТЛЕТ ВЫСШЕЙ КАТЕГОРИИ · УРОВЕНЬ BATYR'), findsOneWidget);
      expect(find.textContaining('7840926M2604128KAZ'), findsOneWidget);
    });

    test('Crisis Mode toggles critical physiological metrics in simulator and bridge', () {
      expect(bleBridge.isCrisisDemo, isFalse);

      bleBridge.setDemoCrisis(true);
      expect(bleBridge.isCrisisDemo, isTrue);

      final criticalTelemetry = bleBridge.currentTelemetry;
      expect(criticalTelemetry.heartRate, equals(118));
      expect(criticalTelemetry.hrv, equals(22.0));
      expect(criticalTelemetry.restingHeartRate, equals(78));
      expect(criticalTelemetry.currentStressScore, equals(89));
      expect(criticalTelemetry.currentDayStrain, equals(18.5));

      bleBridge.setDemoCrisis(false);
      expect(bleBridge.isCrisisDemo, isFalse);
    });

    testWidgets('ProfileScreen displays crisis banner and allows one-tap reset', (tester) async {
      bleBridge.setDemoCrisis(true);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(bleBridge: bleBridge),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('⚡ РЕЖИМ «ГРОЗА» АКТИВЕН'), findsOneWidget);
      expect(find.textContaining('ЧСС 118 bpm · ВСР 22 мс'), findsOneWidget);

      // Нажимаем ВЫКЛ на баннере
      await tester.tap(find.text('ВЫКЛ'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(bleBridge.isCrisisDemo, isFalse);
      expect(find.text('⚡ РЕЖИМ «ГРОЗА» АКТИВЕН'), findsNothing);
    });
  });
}
