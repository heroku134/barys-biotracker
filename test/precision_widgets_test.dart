import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barys_biotracker/core/app_colors.dart';
import 'package:barys_biotracker/domain/models/readiness.dart';
import 'package:barys_biotracker/presentation/widgets/precision_card.dart';
import 'package:barys_biotracker/presentation/widgets/precision_recovery_ring.dart';
import 'package:barys_biotracker/presentation/widgets/precision_strain_bar.dart';
import 'package:barys_biotracker/presentation/widgets/precision_sleep_card.dart';
import 'package:barys_biotracker/presentation/widgets/precision_pulse_wave.dart';
import 'package:barys_biotracker/presentation/widgets/precision_coach_card.dart';

void main() {
  group('Precision Athletic UI Components Test Suite', () {
    testWidgets('1. PrecisionCard renders flat surface with hairline border', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrecisionCard(
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
    });

    testWidgets('2. PrecisionRecoveryRing renders score and 3 key metrics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrecisionRecoveryRing(
              score: 94,
              zone: RecoveryZone.optimal,
              hrv: 64.0,
              restingHeartRate: 52,
              skinTempDeviation: 0.2,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1000));

      expect(find.text('RECOVERY'), findsOneWidget);
      expect(find.text('94'), findsOneWidget);
      expect(find.text('OPTIMAL'), findsOneWidget);
      expect(find.text('HRV'), findsOneWidget);
      expect(find.text('64'), findsOneWidget);
      expect(find.text('REST HR'), findsOneWidget);
      expect(find.text('52'), findsOneWidget);
      expect(find.text('SKIN TEMP'), findsOneWidget);
    });

    testWidgets('3. PrecisionStrainBar renders strain value, target range and progress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrecisionStrainBar(
              currentStrain: 12.4,
              targetMin: 10.5,
              targetMax: 13.8,
            ),
          ),
        ),
      );

      expect(find.text('DAY STRAIN'), findsOneWidget);
      expect(find.text('12.4'), findsOneWidget);
      expect(find.text('/ 21.0'), findsOneWidget);
      expect(find.text('10.5 — 13.8'), findsOneWidget);
      expect(find.text('IN TARGET ZONE'), findsOneWidget);
    });

    testWidgets('4. PrecisionSleepCard renders total duration and 4-stage grid', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrecisionSleepCard(
              totalMinutes: 468,
              deepMinutes: 102,
              remMinutes: 116,
              lightMinutes: 224,
              awakeMinutes: 26,
              sleepPerformanceScore: 88,
            ),
          ),
        ),
      );

      expect(find.text('SLEEP SUMMARY'), findsOneWidget);
      expect(find.text('7H 48M'), findsOneWidget);
      expect(find.text('88%'), findsOneWidget);
      expect(find.text('DEEP'), findsOneWidget);
      expect(find.text('REM'), findsOneWidget);
      expect(find.text('LIGHT'), findsOneWidget);
      expect(find.text('AWAKE'), findsOneWidget);
    });

    testWidgets('5. PrecisionPulseWave renders live heart rate and extremes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrecisionPulseWave(
              bpm: 72,
              restingBpm: 52,
              peakBpm: 148,
            ),
          ),
        ),
      );

      expect(find.text('LIVE HEART RATE'), findsOneWidget);
      expect(find.text('72'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
      expect(find.text('52'), findsOneWidget);
      expect(find.text('148'), findsOneWidget);
    });

    testWidgets('6. PrecisionCoachCard renders plain grotesk athletic readout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrecisionCoachCard(
              title: 'PHYSIOLOGICAL READOUT',
              insight: 'Autonomic recovery is optimal.',
              actionLabel: 'PRIMED FOR LOAD',
            ),
          ),
        ),
      );

      expect(find.text('PHYSIOLOGICAL READOUT'), findsOneWidget);
      expect(find.text('Autonomic recovery is optimal.'), findsOneWidget);
      expect(find.text('PRIMED FOR LOAD'), findsOneWidget);
    });
  });
}
