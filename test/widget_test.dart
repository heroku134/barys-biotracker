import 'package:flutter_test/flutter_test.dart';
import 'package:barys_biotracker/domain/avatar/avatar_manager.dart';
import 'package:barys_biotracker/domain/intelligence/healthspan_engine.dart';
import 'package:barys_biotracker/domain/intelligence/readiness_engine.dart';
import 'package:barys_biotracker/domain/intelligence/sleep_engine.dart';
import 'package:barys_biotracker/domain/intelligence/strain_engine.dart';
import 'package:barys_biotracker/domain/models/personal_baseline.dart';
import 'package:barys_biotracker/domain/models/readiness.dart';
import 'package:barys_biotracker/domain/models/telemetry.dart';

void main() {
  group('Physiological Engine Tests (CIRCA / Whoop 5.0 Model)', () {
    const baseline = PersonalBaseline(
      meanHrv: 64.0,
      meanRhr: 52,
      meanRespiratoryRate: 14.4,
      baselineSkinTemp: 36.4,
      baselineSleepNeedMinutes: 480, // 8 часов
      calibrationDaysDone: 14,
      sleepDebtMinutes: 20,
    );

    test('1. Recovery: Calculates score based on 5 biomarkers and personal baseline', () {
      final telemetry = BleTelemetry(
        heartRate: 70,
        hrv: 72.0, // Выше личной базы 64
        restingHeartRate: 50, // Ниже личной базы 52
        respiratoryRate: 14.2,
        skinTempDeviation: 0.1,
        sleepMinutes: 490,
        timeInBedMinutes: 520,
        sleepEfficiency: 0.94,
        sleepConsistency: 0.90,
        restorativeSleepRatio: 0.80,
        isOffWrist: false,
        timestamp: DateTime.now(),
      );

      final result = ReadinessEngine.calculate(telemetry, baseline: baseline);
      expect(result.score, greaterThanOrEqualTo(67));
      expect(result.zone, equals(RecoveryZone.optimal));
      expect(result.isOffWrist, isFalse);
      expect(result.isCalibrating, isFalse);
    });

    test('2. Off-wrist filter: Rejects night data when watch is off-wrist', () {
      final telemetry = BleTelemetry(
        isOffWrist: true,
        timestamp: DateTime.now(),
      );

      final result = ReadinessEngine.calculate(telemetry, baseline: baseline);
      expect(result.isOffWrist, isTrue);
      expect(result.score, equals(0));
      expect(result.primaryNegativeFactor, contains('снят'));
    });

    test('3. Calibration Mode: Flags first 14 days without overconfident labels', () {
      const calibratingBaseline = PersonalBaseline(calibrationDaysDone: 5);
      final telemetry = BleTelemetry(timestamp: DateTime.now());

      final result = ReadinessEngine.calculate(telemetry, baseline: calibratingBaseline);
      expect(result.isCalibrating, isTrue);
      expect(result.calibrationDay, equals(5));
    });

    test('4. Strain Engine: Computes Whoop TRIMP 0-21 and target budget', () {
      // 5 зон: [Z1, Z2, Z3, Z4, Z5]
      final zoneMinutes = [60, 45, 25, 12, 3];
      final strain = StrainEngine.calculateStrainFromZones(zoneMinutes);

      expect(strain, greaterThanOrEqualTo(10.0));
      expect(strain, lessThanOrEqualTo(21.0));

      final evalOptimal = StrainEngine.evaluate(
        currentStrain: 12.5,
        recoveryZone: RecoveryZone.optimal,
        zoneMinutes: zoneMinutes,
      );
      // При Optimal цель 14.0 - 18.0
      expect(evalOptimal.targetStrainMin, equals(14.0));
      expect(evalOptimal.remainingToTarget, closeTo(1.5, 0.1));
    });

    test('5. Sleep Engine: Calculates dynamic Sleep Need = Base + 14d Debt + Strain surcharge', () {
      final telemetry = BleTelemetry(
        yesterdayStrain: 16.0, // Высокая нагрузка
        sleepMinutes: 440,
        timeInBedMinutes: 490,
        timestamp: DateTime.now(),
      );

      final analysis = SleepEngine.calculate(
        telemetry: telemetry,
        baseline: baseline,
        targetWakeHour: 7,
        targetWakeMinute: 0,
      );

      // Base 480 + Debt (20 * 0.25 = 5) + Strain ((16 - 10) * 6.5 = 39) = ~524 мин (8ч 44м)
      expect(analysis.sleepNeedMinutes, greaterThan(baseline.baselineSleepNeedMinutes));
      expect(analysis.strainSurchargeMinutes, greaterThan(0));
      expect(analysis.optimalBedtime, isNotEmpty);
      expect(analysis.hypnogram, isNotEmpty);
    });

    test('6. Healthspan Engine: Calculates CIRCA biological age and VO2max', () {
      final health = HealthspanEngine.calculate(
        chronologicalAge: 34,
        restingHeartRate: 50,
        weeklyZone2Minutes: 180,
        weeklyZone5Minutes: 25,
        sleepConsistency: 0.90,
        rhrSixMonthDelta: -3.0,
      );

      expect(health.circaBiologicalAge, lessThan(34.0));
      expect(health.ageDeltaYears, lessThan(0.0)); // Моложе паспорта
      expect(health.estimatedVo2Max, greaterThan(45.0));
    });

    test('7. Avatar Manager: Charged ONLY when Recovery >= 75 AND sleep debt < 30m', () {
      final highRecTelemetry = BleTelemetry(
        hrv: 78.0,
        restingHeartRate: 49,
        sleepMinutes: 500,
        sleepEfficiency: 0.95,
        sleepConsistency: 0.92,
        restorativeSleepRatio: 0.85,
        timestamp: DateTime.now(),
      );

      // Малый долг сна -> Charged
      const lowDebtBase = PersonalBaseline(sleepDebtMinutes: 15);
      final stateCharged = AvatarManager.calculateState(
        highRecTelemetry,
        baseline: lowDebtBase,
        currentTime: DateTime(2026, 9, 20, 14, 0),
      );
      expect(stateCharged, equals(AvatarVisualState.charged));

      // Большой долг сна (50 мин) -> Normal, не Charged!
      const highDebtBase = PersonalBaseline(sleepDebtMinutes: 50);
      final stateNormal = AvatarManager.calculateState(
        highRecTelemetry,
        baseline: highDebtBase,
        currentTime: DateTime(2026, 9, 20, 14, 0),
      );
      expect(stateNormal, equals(AvatarVisualState.normal));
    });

    test('8. Avatar Manager: All 6 Scenarios Verification', () {
      final daytime = DateTime(2026, 9, 20, 14, 0);

      // 1. Tired on low recovery (<34)
      final tiredTelemetry = BleTelemetry(
        hrv: 22.0,
        restingHeartRate: 76,
        sleepMinutes: 210,
        sleepEfficiency: 0.62,
        sleepConsistency: 0.50,
        restorativeSleepRatio: 0.25,
        respiratoryRate: 17.8,
        skinTempDeviation: 0.85,
        timestamp: daytime,
      );
      expect(
        AvatarManager.calculateState(tiredTelemetry, currentTime: daytime),
        equals(AvatarVisualState.tired),
      );

      // 2. Tired on yesterday strain > 16
      final normalTelemetry = BleTelemetry(
        hrv: 62.0,
        restingHeartRate: 54,
        timestamp: daytime,
      );
      expect(
        AvatarManager.calculateState(
          normalTelemetry,
          baseline: const PersonalBaseline(yesterdayStrain: 17.5),
          currentTime: daytime,
        ),
        equals(AvatarVisualState.tired),
      );

      // 3. Sleep on late night (> 22:00)
      final nightTime = DateTime(2026, 9, 20, 23, 15);
      expect(
        AvatarManager.calculateState(normalTelemetry, currentTime: nightTime),
        equals(AvatarVisualState.sleep),
      );

      // 4. Sleep on severe sleep debt (>= 90m)
      expect(
        AvatarManager.calculateState(
          normalTelemetry,
          baseline: const PersonalBaseline(sleepDebtMinutes: 100),
          currentTime: daytime,
        ),
        equals(AvatarVisualState.sleep),
      );

      // 5. Meditation on daytime stress > 65
      final stressedTelemetry = BleTelemetry(
        hrv: 60.0,
        restingHeartRate: 55,
        currentStressScore: 72,
        timestamp: daytime,
      );
      expect(
        AvatarManager.calculateState(stressedTelemetry, currentTime: daytime),
        equals(AvatarVisualState.meditation),
      );

      // 6. PostWorkout on recorded workout
      AvatarManager.recordWorkout(8.0);
      expect(
        AvatarManager.calculateState(normalTelemetry, currentTime: DateTime.now()),
        equals(AvatarVisualState.postWorkout),
      );
    });
  });
}
