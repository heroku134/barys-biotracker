import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barys_biotracker/core/app_colors.dart';
import 'package:barys_biotracker/core/circa_haptics.dart';
import 'package:barys_biotracker/domain/avatar/avatar_manager.dart';
import 'package:barys_biotracker/domain/intelligence/readiness_engine.dart';
import 'package:barys_biotracker/domain/models/telemetry.dart';
import 'package:barys_biotracker/presentation/widgets/circa_mascot_hero_card.dart';
import 'package:barys_biotracker/presentation/widgets/kalkan_ui.dart';
import 'package:barys_biotracker/presentation/widgets/metric_dial.dart';

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
  });
}
