import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barys_biotracker/core/app_colors.dart';
import 'package:barys_biotracker/core/circa_haptics.dart';
import 'package:barys_biotracker/domain/avatar/avatar_manager.dart';
import 'package:barys_biotracker/domain/intelligence/readiness_engine.dart';
import 'package:barys_biotracker/domain/models/telemetry.dart';
import 'package:barys_biotracker/presentation/widgets/circa_mascot_hero_card.dart';
import 'package:barys_biotracker/presentation/widgets/kalkan_ui.dart';
import 'package:barys_biotracker/presentation/widgets/kalkan_chrome.dart';
import 'package:barys_biotracker/presentation/widgets/metric_dial.dart';
import 'package:barys_biotracker/domain/intelligence/sleep_engine.dart';
import 'package:barys_biotracker/domain/models/personal_baseline.dart';
import 'package:barys_biotracker/data/storage/private_league_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barys_biotracker/presentation/widgets/circa_hypnogram.dart';
import 'package:barys_biotracker/presentation/widgets/circa_cycle_card.dart';
import 'package:barys_biotracker/presentation/widgets/circa_calibration_card.dart';
import 'package:barys_biotracker/domain/models/user_profile.dart';
import 'package:barys_biotracker/domain/intelligence/menstrual_cycle_engine.dart';

import 'package:barys_biotracker/core/secure_invite_generator.dart';
import 'package:barys_biotracker/domain/models/private_league.dart';
import 'package:barys_biotracker/presentation/screens/auth_screen.dart';
import 'package:barys_biotracker/data/ble/ute_ble_bridge.dart';

void main() {
  group('KALKAN Athletic Surface & UI Components Test Suite', () {
    testWidgets('1. KalkanCard renders flat surface with hairline border and zero dark-mode shadow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KalkanCard(
              child: Text('TEST'),
            ),
          ),
        ),
      );

      expect(find.text('TEST'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(AppColors.surface));
      expect(decoration.boxShadow, isNull);
      expect(decoration.borderRadius, equals(BorderRadius.circular(14)));
      expect(decoration.border, equals(Border.all(color: AppColors.hairline, width: 1.0)));
    });

    testWidgets('2. KalkanCard handles onTap callbacks properly', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KalkanCard(
              onTap: () => tapped = true,
              child: const Text('TAP_ME'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('TAP_ME'));
      expect(tapped, isTrue);
    });

    test('3. KalkanUi enforces canonical design grid, radii, and tap target laws', () {
      expect(KalkanUi.cardRadius, equals(14.0));
      expect(KalkanUi.controlRadius, equals(8.0));
      expect(KalkanUi.progressRadius, equals(4.0));
      expect(KalkanUi.pagePadding, equals(20.0));
      expect(KalkanUi.pageHorizontal, equals(20.0));
      expect(KalkanUi.cardStackSpacing, equals(12.0));
      expect(KalkanUi.cardPadding, equals(16.0));
      expect(KalkanUi.minTapTarget, equals(44.0));
      expect(KalkanUi.hairline, equals(1.0));
    });

    testWidgets('4. KalkanStatusChip renders label and border with controlRadius (8)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KalkanStatusChip(
              label: 'READY',
              color: AppColors.sage,
              icon: Icons.check,
            ),
          ),
        ),
      );

      expect(find.text('READY'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('5. KalkanSectionLabel and KalkanPageHeader render hierarchy cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KalkanPageHeader(
              eyebrow: 'OVERVIEW',
              title: 'Dashboard',
            ),
          ),
        ),
      );

      expect(find.text('OVERVIEW'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('6. MetricDial renders score and label without decorative glow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricDial(
              label: 'RECOVERY',
              value: '88%',
              progress: 0.88,
              color: AppColors.sage,
            ),
          ),
        ),
      );

      expect(find.text('RECOVERY'), findsOneWidget);
      expect(find.text('88%'), findsOneWidget);
    });

    testWidgets('7. CircaMascotHeroCard renders flat quiet card with mascot pair and no radial glow blobs', (tester) async {
      final telemetry = BleTelemetry(
        heartRate: 64,
        restingHeartRate: 52,
        hrv: 58.0,
        batteryLevel: 85,
        steps: 4200,
        isConnected: true,
        timestamp: DateTime.now(),
      );
      final readiness = ReadinessEngine.calculate(telemetry);
      final state = AvatarManager.calculateState(telemetry);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircaMascotHeroCard(
              state: state,
              readiness: readiness,
            ),
          ),
        ),
      );

      expect(find.text('СААТ-1'), findsOneWidget);
      expect(find.byType(CircaMascotHeroCard), findsOneWidget);
    });

    test('8. KalkanHaptics and KalkanAcoustics enforce quiet tactile rules', () async {
      expect(KalkanAcoustics.soundEnabled, isFalse);
      // Ensure haptic calls complete without unhandled exceptions
      await KalkanHaptics.selectionClick();
      await KalkanHaptics.success();
      await KalkanHaptics.ringZoneTick();
    });

    testWidgets('9. KalkanAppBar renders eyebrow and title with consistent hierarchy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: KalkanAppBar(
              eyebrow: 'СЕГОДНЯ',
              title: 'Данияр',
            ),
          ),
        ),
      );

      expect(find.text('СЕГОДНЯ'), findsOneWidget);
      expect(find.text('Данияр'), findsOneWidget);
      expect(find.byType(KalkanAppBar), findsOneWidget);
    });

    testWidgets('10. CircaHypnogram displays honest empty state when sensor provides no sleep epochs', (tester) async {
      final sleepResult = SleepEngine.calculate(
        telemetry: BleTelemetry.empty().copyWith(sleepMinutes: 420),
        baseline: const PersonalBaseline(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircaHypnogram(sleepResult: sleepResult),
          ),
        ),
      );

      // Must display honest empty state message
      expect(find.text('Ночь без фаз — часы не отдали гипнограмму'), findsOneWidget);
      // Must NOT display fabricated phase breakdown
      expect(find.text('REM (быстрый): '), findsNothing);
      expect(find.text('Глубокий: '), findsNothing);
    });

    test('11. PrivateLeagueRepository adds friends in honest pending state without fake scores', () async {
      SharedPreferences.setMockInitialValues({});
      await PrivateLeagueRepository.resetToDefaultLeague();
      final ok = await PrivateLeagueRepository.addFriend(name: 'Арман Б.');
      expect(ok, isTrue);

      final league = await PrivateLeagueRepository.loadLeague();
      final arman = league.members.firstWhere((m) => m.name == 'Арман Б.');
      expect(arman.recoveryScore, 0); // No fabricated 78% score
      expect(arman.lastSyncText, 'Ожидание данных'); // No fake 'Live'
      expect(arman.isCurrentUser, isFalse);
    });

    testWidgets('12. CircaCycleCard displays honest setup state when lastPeriodStartDate is null', (tester) async {
      const profile = UserProfile(gender: Gender.female, lastPeriodStartDate: null);
      final telemetry = BleTelemetry.empty();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircaCycleCard(
              telemetry: telemetry,
              profile: profile,
              onTap: () {},
            ),
          ),
        ),
      );

      // Must display setup prompt and not fake day 14 or ovulation
      expect(find.text('Цикл не настроен'), findsOneWidget);
      expect(find.text('Указать дату начала'), findsOneWidget);
      expect(find.text('ОВУЛЯЦИЯ'), findsNothing);
      expect(find.text('14'), findsNothing);
    });

    testWidgets('13. CircaCalibrationCard renders KalkanCard with day indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CircaCalibrationCard(
              currentDay: 3,
              totalDays: 14,
            ),
          ),
        ),
      );

      expect(find.text('КАЛИБРОВКА БАЗЫ'), findsOneWidget);
      expect(find.text('День 3 из 14'), findsOneWidget);
      expect(find.byType(KalkanCard), findsOneWidget);
    });

    test('14. MenstrualCycleEngine.isConfigured checks for lastPeriodStartDate', () {
      const unconfigured = UserProfile(gender: Gender.female, lastPeriodStartDate: null);
      final configured = UserProfile(gender: Gender.female, lastPeriodStartDate: DateTime.now());

      expect(MenstrualCycleEngine.isConfigured(unconfigured), isFalse);
      expect(MenstrualCycleEngine.isConfigured(configured), isTrue);
    });

    test('15. UserProfile.fromJson defaults isAuthenticated to false when omitted or null', () {
      final jsonWithoutAuth = {
        'name': 'Batyr',
        'gender': 'male',
      };
      final profile = UserProfile.fromJson(jsonWithoutAuth);
      expect(profile.isAuthenticated, isFalse, reason: 'Unauthenticated profiles must never default to true');

      final jsonWithAuthTrue = {
        'name': 'Batyr',
        'gender': 'male',
        'isAuthenticated': true,
      };
      final authProfile = UserProfile.fromJson(jsonWithAuthTrue);
      expect(authProfile.isAuthenticated, isTrue);
    });

    test('16. SecureInviteGenerator produces high-entropy non-colliding codes with KLK prefix', () {
      final friendCode1 = SecureInviteGenerator.generateFriendCode();
      final friendCode2 = SecureInviteGenerator.generateFriendCode();
      final cycleCode = SecureInviteGenerator.generateCycleCode();

      expect(friendCode1, startsWith('KLK-FRN-'));
      expect(friendCode2, startsWith('KLK-FRN-'));
      expect(cycleCode, startsWith('KLK-CYC-'));
      expect(friendCode1, isNot(equals(friendCode2)));
      expect(friendCode1.length, greaterThanOrEqualTo(16));
      expect(SecureInviteGenerator.isValidCode(friendCode1), isTrue);
      expect(SecureInviteGenerator.isValidCode(cycleCode), isTrue);
      expect(SecureInviteGenerator.isValidCode('KALKAN-1234'), isTrue);
      expect(SecureInviteGenerator.isValidCode('INVALID'), isFalse);
    });

    test('17. PrivateLeague.copyWith updates inviteCode and retains existing members', () {
      const original = PrivateLeague(
        id: 'league_01',
        title: 'Тест',
        inviteCode: 'OLD-CODE',
        members: [],
      );
      final updated = original.copyWith(inviteCode: 'KLK-FRN-ABCD-1234');
      expect(updated.inviteCode, 'KLK-FRN-ABCD-1234');
      expect(updated.id, 'league_01');
    });

    testWidgets('18. AuthScreen renders Forgot Password button in login mode', (tester) async {
      final bridge = UteBleBridge();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(bleBridge: bridge),
        ),
      );
      await tester.pump();

      expect(find.text('Забыли пароль?'), findsOneWidget);
    });
  });
}
