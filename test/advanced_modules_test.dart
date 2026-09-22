import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barys_biotracker/domain/intelligence/baseline_calibration_manager.dart';
import 'package:barys_biotracker/data/services/app_icon_service.dart';
import 'package:barys_biotracker/data/services/health_sync_service.dart';
import 'package:barys_biotracker/data/services/live_activity_service.dart';
import 'package:barys_biotracker/domain/models/workout_session.dart';
import 'package:barys_biotracker/firebase_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Advanced Modules Test Suite', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. BaselineCalibrationManager calculates rolling baseline and confidence', () async {
      final initialBaseline = await BaselineCalibrationManager.loadCalibratedBaseline();
      expect(initialBaseline.meanHrv, 64.0);
      expect(initialBaseline.meanRhr, 52);

      // Add night sample
      final updated = await BaselineCalibrationManager.recordNightSample(
        hrv: 70.0,
        rhr: 50,
        respiratoryRate: 14.2,
        skinTemp: 36.5,
        sleepMinutes: 480,
      );

      expect(updated.meanHrv, 70.0);
      expect(updated.meanRhr, 50);

      // Check confidence calculations
      expect(BaselineCalibrationManager.calculateConfidence(1), 30);
      expect(BaselineCalibrationManager.calculateConfidence(7), 70);
      expect(BaselineCalibrationManager.calculateConfidence(14), 100);

      expect(
        BaselineCalibrationManager.getCalibrationStatusLabel(14),
        'БЕЙЗЛАЙН СКАЛИБРОВАН (100%)',
      );
    });

    test('2. HealthSyncService manages auto-sync and sleep stages', () async {
      final autoSync = await HealthSyncService.isAutoSyncEnabled();
      expect(autoSync, true);

      await HealthSyncService.setAutoSyncEnabled(false);
      expect(await HealthSyncService.isAutoSyncEnabled(), false);

      final stages = await HealthSyncService.fetchNightSleepStages();
      expect(stages.deepMinutes, 98);
      expect(stages.remMinutes, 112);
      expect(stages.totalMinutes, 468);
      expect(stages.efficiency, 96.6);

      final workout = CompletedWorkout(
        id: 'w_test_1',
        sport: SportType.runOutdoor,
        startedAt: DateTime.now().subtract(const Duration(minutes: 45)),
        durationSeconds: 2700,
        calories: 420,
        distanceKm: 6.2,
        avgHr: 148,
        maxHr: 172,
        strain: 13.5,
        xpEarned: 150,
      );

      final exported = await HealthSyncService.exportWorkoutToHealth(
        workout: workout,
        strain: 13.5,
        activeCalories: 420,
      );
      expect(exported, true);
    });

    test('3. LiveActivityService initial state check', () {
      expect(LiveActivityService.isLiveActivityActive, false);
    });

    test('4. AppIconService manages dark and light icon switching and persistence', () async {
      await AppIconService.init();
      expect(AppIconService.currentIcon.value, AppIconVariant.dark);

      await AppIconService.setIcon(AppIconVariant.light);
      expect(AppIconService.currentIcon.value, AppIconVariant.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kalkan_app_icon_variant'), 'light');

      await AppIconService.setIcon(AppIconVariant.dark);
      expect(AppIconService.currentIcon.value, AppIconVariant.dark);
      expect(prefs.getString('kalkan_app_icon_variant'), 'dark');
    });

    test('5. DefaultFirebaseOptions validates project configuration', () {
      expect(DefaultFirebaseOptions.android.projectId, 'watch-ba720');
      expect(DefaultFirebaseOptions.ios.projectId, 'watch-ba720');
      expect(DefaultFirebaseOptions.ios.iosBundleId, 'kalkan.comp');
      expect(DefaultFirebaseOptions.android.apiKey.isNotEmpty, true);
      expect(DefaultFirebaseOptions.ios.apiKey.isNotEmpty, true);
    });
  });
}
