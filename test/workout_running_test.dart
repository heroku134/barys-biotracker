import 'package:flutter_test/flutter_test.dart';
import 'package:barys_biotracker/domain/models/workout_session.dart';
import 'package:barys_biotracker/data/storage/calibration_store.dart';
import 'package:barys_biotracker/data/storage/private_league_repository.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:barys_biotracker/data/storage/partner_cycle_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Workout Running & GPS Route Tests', () {
    test('CompletedWorkout serializes and deserializes route coordinates and running telemetry', () {
      final workout = CompletedWorkout(
        id: 'test_run_01',
        sport: SportType.runOutdoor,
        startedAt: DateTime(2026, 9, 22, 18, 0),
        durationSeconds: 1800, // 30 mins
        calories: 320,
        distanceKm: 5.25,
        avgHr: 154,
        maxHr: 176,
        strain: 12.4,
        xpEarned: 124,
        routeCoordinates: [
          [43.2389, 76.8897],
          [43.2395, 76.8905],
          [43.2410, 76.8920],
        ],
        avgPaceMinPerKm: 5.71,
        steps: 4850,
        cadence: 162,
        hrZoneSeconds: [120, 300, 780, 480, 120],
      );

      expect(workout.hasRoute, isTrue);
      expect(workout.durationFormatted, '30м 00с');
      expect(workout.paceFormatted, contains("5'43\" / км"));

      final json = workout.toJson();
      final fromJson = CompletedWorkout.fromJson(json);

      expect(fromJson.id, workout.id);
      expect(fromJson.sport, SportType.runOutdoor);
      expect(fromJson.distanceKm, 5.25);
      expect(fromJson.routeCoordinates.length, 3);
      expect(fromJson.steps, 4850);
      expect(fromJson.cadence, 162);
      expect(fromJson.hrZoneSeconds, [120, 300, 780, 480, 120]);
    });

    test('CalibrationStore updates baseline and supports manual days set', () async {
      await CalibrationStore.setCalibrationDays(7);
      final snap = await CalibrationStore.load();
      expect(snap.daysDone, 7);
      expect(snap.isCalibrating, isTrue);

      await CalibrationStore.setCalibrationDays(14);
      final calibratedSnap = await CalibrationStore.load();
      expect(calibratedSnap.daysDone, 14);
      expect(calibratedSnap.isCalibrating, isFalse);
    });

    test('PrivateLeagueRepository loads league without infinite hang', () async {
      final league = await PrivateLeagueRepository.loadLeague();
      expect(league.members.isNotEmpty, isTrue);
      expect(league.members.any((m) => m.isCurrentUser), isTrue);
    });

    test('PartnerCycleRepository handles linking with and without name, and clean unlinking', () async {
      final initial = await PartnerCycleRepository.loadPartnerCycle();
      expect(initial.isLinked, isFalse);

      // Auto-name fallback when empty
      await PartnerCycleRepository.linkPartner(partnerCode: 'KLK-1234');
      final linkedAuto = await PartnerCycleRepository.loadPartnerCycle();
      expect(linkedAuto.isLinked, isTrue);
      expect(linkedAuto.partnerName, 'Партнёр');
      expect(linkedAuto.partnerCode, 'KLK-1234');

      // Named link
      await PartnerCycleRepository.linkPartner(partnerCode: 'KLK-5678', partnerName: 'Айпери');
      final linkedNamed = await PartnerCycleRepository.loadPartnerCycle();
      expect(linkedNamed.isLinked, isTrue);
      expect(linkedNamed.partnerName, 'Айпери');
      expect(linkedNamed.partnerCode, 'KLK-5678');

      // Clean unlinking
      await PartnerCycleRepository.unlinkPartner();
      final unlinked = await PartnerCycleRepository.loadPartnerCycle();
      expect(unlinked.isLinked, isFalse);
      expect(unlinked.partnerName, isEmpty);
      expect(unlinked.partnerCode, isEmpty);
    });
  });
}
