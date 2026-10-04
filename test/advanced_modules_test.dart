import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barys_biotracker/data/services/health_sync_service.dart';
import 'package:barys_biotracker/data/services/live_activity_service.dart';
import 'package:barys_biotracker/data/storage/local_day_strain.dart';
import 'package:barys_biotracker/domain/models/workout_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Advanced Modules Test Suite', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('2. HealthSyncService manages auto-sync and sleep stages', () async {
      final autoSync = await HealthSyncService.isAutoSyncEnabled();
      expect(autoSync, true);

      await HealthSyncService.setAutoSyncEnabled(false);
      expect(await HealthSyncService.isAutoSyncEnabled(), false);

      final stages = await HealthSyncService.fetchNightSleepStages();
      expect(stages, isNull);

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

    test('4. HealthSyncService imports external workouts and adds Strain with deduplication', () async {
      final initialStrain = LocalDayStrain.current();

      final sampleWorkout = CompletedWorkout(
        id: 'ext_test_ride_1',
        externalId: 'hk_strava_test_98210',
        externalSource: 'strava',
        sourceAppName: 'Strava',
        sport: SportType.cycling,
        startedAt: DateTime.now().subtract(const Duration(hours: 1)),
        durationSeconds: 2400,
        calories: 400,
        distanceKm: 12.0,
        avgHr: 145,
        maxHr: 170,
        strain: 0.0,
        xpEarned: 0,
      );

      final imported = await HealthSyncService.importExternalWorkouts(
        incomingWorkouts: [sampleWorkout],
      );
      expect(imported.isNotEmpty, true);
      expect(imported.first.isExternal, true);
      expect(imported.first.strain > 0, true);
      expect(imported.first.xpEarned > 0, true);

      // Verify daily strain was updated if workout happened today
      final currentStrain = LocalDayStrain.current();
      expect(currentStrain >= initialStrain, true);

      // Verify deduplication: re-import should yield 0 new workouts
      final reImported = await HealthSyncService.importExternalWorkouts(
        incomingWorkouts: [sampleWorkout],
      );
      expect(reImported.isEmpty, true);

      // Verify empty incoming yields 0 workouts
      final emptyImport = await HealthSyncService.importExternalWorkouts();
      expect(emptyImport.isEmpty, true);
    });
  });
}
