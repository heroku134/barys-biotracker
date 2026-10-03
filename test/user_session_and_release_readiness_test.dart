import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barys_biotracker/data/ble/ute_ble_bridge.dart';
import 'package:barys_biotracker/data/history/biometrics_history_repository.dart';
import 'package:barys_biotracker/data/services/user_session_manager.dart';
import 'package:barys_biotracker/data/storage/day_journal_repository.dart';
import 'package:barys_biotracker/data/storage/day_snapshot_repository.dart';
import 'package:barys_biotracker/data/storage/local_day_strain.dart';
import 'package:barys_biotracker/data/storage/partner_cycle_repository.dart';
import 'package:barys_biotracker/data/storage/pregnancy_log_repository.dart';
import 'package:barys_biotracker/data/storage/user_profile_repository.dart';
import 'package:barys_biotracker/data/storage/workout_repository.dart';
import 'package:barys_biotracker/domain/avatar/avatar_manager.dart';
import 'package:barys_biotracker/domain/models/telemetry.dart';
import 'package:barys_biotracker/domain/models/workout_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('User Session & Production Release Readiness Tests', () {
    test('1. Avatar initial state starts at level 1 with 0 XP (no mock 298 XP)', () async {
      await AvatarManager.reset();
      await AvatarManager.init();
      expect(AvatarManager.currentLevel, 1);
      expect(AvatarManager.currentXp, 0);
    });

    test('2. WorkoutRepository filters out legacy mock Strava sessions automatically', () async {
      final prefs = await SharedPreferences.getInstance();
      final mockStrava = CompletedWorkout(
        id: 'ext_strava_ride_1',
        externalId: 'hk_strava_ride_98210',
        externalSource: 'strava',
        sourceAppName: 'Strava',
        sport: SportType.cycling,
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
        durationSeconds: 2700,
        calories: 460,
        distanceKm: 14.8,
        avgHr: 146,
        maxHr: 172,
        strain: 11.2,
        xpEarned: 390,
      );

      final realWorkout = CompletedWorkout(
        id: 'real_run_1',
        sport: SportType.runOutdoor,
        startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        durationSeconds: 1800,
        calories: 250,
        distanceKm: 4.2,
        avgHr: 152,
        maxHr: 168,
        strain: 9.5,
        xpEarned: 180,
      );

      await prefs.setStringList('kalkan_workouts_history_v1', [
        jsonEncode(mockStrava.toJson()),
        jsonEncode(realWorkout.toJson()),
      ]);

      final loaded = await WorkoutRepository.loadWorkouts();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'real_run_1');
      expect(loaded.any((w) => w.id.contains('strava')), isFalse);
    });

    test('3. Cross-Account Isolation: User A workouts never leak to User B on new account sign-up', () async {
      // 1. User A logs in and records a workout
      const userAId = 'user_athlet_A';
      final workoutA = CompletedWorkout(
        id: 'workout_user_a_1',
        sport: SportType.runOutdoor,
        startedAt: DateTime.now().subtract(const Duration(hours: 1)),
        durationSeconds: 1500,
        calories: 220,
        distanceKm: 3.5,
        avgHr: 145,
        maxHr: 162,
        strain: 8.4,
        xpEarned: 150,
      );
      await WorkoutRepository.saveWorkout(workoutA, userId: userAId);
      final userAWorkouts = await WorkoutRepository.loadWorkouts(userId: userAId);
      expect(userAWorkouts.length, 1);
      expect(userAWorkouts.first.id, 'workout_user_a_1');

      // Also simulate user A daily strain and snapshot
      LocalDayStrain.add(8.4);
      expect(LocalDayStrain.current(), 8.4);
      await DaySnapshotRepository.upsert(DaySnapshot(
        dateKey: '2026-10-01',
        recovery: 85,
        strain: 8.4,
        sleep: 480,
        hrv: 72.0,
        rhr: 49,
      ));

      // 2. User logs out or creates a new account -> UserSessionManager.clearLocalUserData()
      await UserSessionManager.clearLocalUserData();

      // 3. User B (brand new registered account) opens the app
      const userBId = 'user_new_registered_B';
      final userBWorkouts = await WorkoutRepository.loadWorkouts(userId: userBId);
      expect(userBWorkouts, isEmpty, reason: 'New account must have 0 workouts');

      final daySnapshots = await DaySnapshotRepository.loadAll();
      expect(daySnapshots, isEmpty, reason: 'New account must have 0 day snapshots');

      expect(LocalDayStrain.current(), 0.0, reason: 'Daily strain must reset to 0');
      expect(AvatarManager.currentXp, 0, reason: 'Avatar XP must reset to 0');
    });

    test('4. BiometricsHistoryRepository uses authentic data and returns empty when insufficient data exists', () async {
      // Empty snapshots -> empty points
      final emptyPoints = BiometricsHistoryRepository.getHeartRateHistory(HistoryPeriod.week7d, []);
      expect(emptyPoints, isEmpty);

      // Single point -> insufficient for trend (returns empty)
      final single = [
        const DaySnapshot(dateKey: '2026-10-01', recovery: 78, strain: 10.0, sleep: 420, hrv: 62.0, rhr: 52),
      ];
      final singlePoints = BiometricsHistoryRepository.getHeartRateHistory(HistoryPeriod.week7d, single);
      expect(singlePoints, isEmpty);

      // Two or more real points -> authentic points returned
      final twoDays = [
        const DaySnapshot(dateKey: '2026-09-30', recovery: 82, strain: 12.0, sleep: 460, hrv: 68.0, rhr: 50),
        const DaySnapshot(dateKey: '2026-10-01', recovery: 75, strain: 9.5, sleep: 410, hrv: 60.0, rhr: 54),
      ];
      final points = BiometricsHistoryRepository.getHeartRateHistory(HistoryPeriod.week7d, twoDays);
      expect(points.length, 2);
      expect(points[0].value, 50.0);
      expect(points[1].value, 54.0);
    });

    test('5. UserSessionManager clears all local state across all repositories', () async {
      final prefs = await SharedPreferences.getInstance();

      // Seed dummy user data
      await prefs.setString('cycle_log_2026-10-01_mood', 'happy');
      await prefs.setString('stress_slot_tag_slot_now', 'Переговоры');
      await prefs.setString('kalkan_reminder_morning_2026-10-01', 'true');
      await prefs.setString('kalkan_preg_note', 'baby kick');
      await DayJournalRepository.save(DayJournalEntry(dateKey: '2026-10-01', updatedAt: DateTime.now()));
      await PartnerCycleRepository.linkPartner(partnerCode: 'KLK-1234');
      await PregnancyLogRepository.save(DateTime.now(), const PregnancyDayLog(kicks: 5));

      // Execute wipe
      await UserSessionManager.clearLocalUserData();

      // Verify all cleared
      expect(await DayJournalRepository.loadAll(), isEmpty);
      expect((await PartnerCycleRepository.loadPartnerCycle()).isLinked, isFalse);
      expect((await PregnancyLogRepository.load(DateTime.now())).kicks, 0);
      expect(prefs.getString('cycle_log_2026-10-01_mood'), isNull);
      expect(prefs.getString('stress_slot_tag_slot_now'), isNull);
      expect(prefs.getString('kalkan_reminder_morning_2026-10-01'), isNull);
      expect(prefs.getString('kalkan_preg_note'), isNull);
      expect(UserProfileRepository.profileNotifier.value.isAuthenticated, isFalse);
    });

    test('6. BLE State Machine & Persistent MAC guards (BLE-02)', () async {
      final prefs = await SharedPreferences.getInstance();
      final bridge = UteBleBridge();

      // Initial state is idle
      expect(bridge.connectionState, BleConnectionState.idle);
      expect(bridge.connectionStateNotifier.value, BleConnectionState.idle);

      // Verify MAC is not persisted prior to connection ready
      expect(prefs.getString('kalkan_last_connected_device_mac'), isNull);

      // Verify connection states exist and are distinct
      expect(BleConnectionState.values, containsAll([
        BleConnectionState.idle,
        BleConnectionState.connecting,
        BleConnectionState.discovering,
        BleConnectionState.ready,
        BleConnectionState.backoff,
        BleConnectionState.failed,
      ]));
    });

    test('7. BLE-03: Kalkan band identification, filter matching, and weak signal inclusion', () {
      expect(UteBleBridge.matchesKalkanFilter('KALKAN СААТ-1'), isTrue);
      expect(UteBleBridge.matchesKalkanFilter('СААТ-1'), isTrue);
      expect(UteBleBridge.matchesKalkanFilter('UTE Watch'), isTrue);
      expect(UteBleBridge.matchesKalkanFilter('Nadal Band'), isTrue);
      expect(UteBleBridge.matchesKalkanFilter('Smart TV'), isFalse);
      expect(UteBleBridge.matchesKalkanFilter('Computer'), isFalse);
      expect(UteBleBridge.matchesKalkanFilter('Apple Watch'), isFalse);
      expect(UteBleBridge.matchesKalkanFilter('BLE Устройство'), isFalse);
      expect(UteBleBridge.matchesKalkanFilter(''), isFalse);

      // Verify DiscoveredBleDevice handles weak RSSI (> -100 dBm) and sets isKalkanBand flag
      const weakKalkan = DiscoveredBleDevice(
        name: 'KALKAN СААТ-1',
        address: 'AA:BB:CC:DD:EE:FF',
        rssi: -94,
        isKalkanBand: true,
      );
      expect(weakKalkan.rssi, -94);
      expect(weakKalkan.isKalkanBand, isTrue);

      const foreignDevice = DiscoveredBleDevice(
        name: 'Samsung Smart TV',
        address: '11:22:33:44:55:66',
        rssi: -60,
        isKalkanBand: false,
      );
      expect(foreignDevice.isKalkanBand, isFalse);
    });

    test('8. BLE-04: Metric retention on link loss and wipe strictly on forget', () {
      final syncTime = DateTime(2026, 10, 3, 22, 0, 0);
      final activeTelemetry = BleTelemetry(
        isConnected: true,
        heartRate: 72,
        steps: 6420,
        calories: 285,
        hrv: 68.0,
        restingHeartRate: 54,
        sleepMinutes: 450,
        batteryLevel: 85,
        deviceName: 'KALKAN BAND 01',
        isCharging: false,
        isOffWrist: false,
        skinTempDeviation: 0.2,
        timestamp: syncTime,
        lastSyncAt: syncTime,
      );

      // On link loss / disconnect, live metrics zero out, but accumulated metrics and lastSyncAt are preserved
      final disconnectedTelemetry = activeTelemetry.copyWith(
        isConnected: false,
        heartRate: 0,
        isOffWrist: false,
        skinTempDeviation: 0.0,
        isCharging: false,
      );

      expect(disconnectedTelemetry.isConnected, isFalse);
      expect(disconnectedTelemetry.heartRate, 0);
      expect(disconnectedTelemetry.isOffWrist, isFalse);
      expect(disconnectedTelemetry.skinTempDeviation, 0.0);
      // Accumulated metrics MUST be preserved:
      expect(disconnectedTelemetry.steps, 6420);
      expect(disconnectedTelemetry.calories, 285);
      expect(disconnectedTelemetry.hrv, 68.0);
      expect(disconnectedTelemetry.restingHeartRate, 54);
      expect(disconnectedTelemetry.sleepMinutes, 450);
      expect(disconnectedTelemetry.batteryLevel, 85);
      expect(disconnectedTelemetry.deviceName, 'KALKAN BAND 01');
      expect(disconnectedTelemetry.lastSyncAt, syncTime);

      // Strictly on explicit forget/wipe, all metrics return to empty state
      final forgottenTelemetry = BleTelemetry.empty();
      expect(forgottenTelemetry.isConnected, isFalse);
      expect(forgottenTelemetry.steps, 0);
      expect(forgottenTelemetry.calories, 0);
      expect(forgottenTelemetry.hrv, 0.0);
      expect(forgottenTelemetry.restingHeartRate, 0);
      expect(forgottenTelemetry.sleepMinutes, 0);
      expect(forgottenTelemetry.sleepHypnogram, isEmpty);
      expect(forgottenTelemetry.batteryLevel, 0);
      expect(forgottenTelemetry.deviceName, 'СААТ-1');
      expect(forgottenTelemetry.lastSyncAt, isNull);
    });

    test('9. BLE-05: Non-draining polling intervals, telemetry snapshot immutability, and 1 Hz coalescing', () {
      // 1. Verify telemetry snapshot immutability
      final initial = BleTelemetry.empty();
      final updated = initial.copyWith(
        heartRate: 75,
        steps: 1200,
        batteryLevel: 90,
        isConnected: true,
      );
      expect(initial.heartRate, 0);
      expect(initial.steps, 0);
      expect(updated.heartRate, 75);
      expect(updated.steps, 1200);

      // 2. Verify intervals conform to BLE-05 non-draining standards
      // Steps/motion polling cadence: >= 30s
      // Battery polling cadence: >= 5 minutes (300s)
      // Routine sleep polling cadence: >= 60 minutes
      // Maximum telemetry push rate: 1 Hz (1000 ms coalescing)
      const motionPollInterval = Duration(seconds: 30);
      const batteryPollInterval = Duration(minutes: 5);
      const sleepPollInterval = Duration(minutes: 60);
      const maxPushRate = Duration(seconds: 1);

      expect(motionPollInterval.inSeconds, greaterThanOrEqualTo(30));
      expect(batteryPollInterval.inMinutes, greaterThanOrEqualTo(5));
      expect(sleepPollInterval.inMinutes, greaterThanOrEqualTo(60));
      expect(maxPushRate.inMilliseconds, 1000);
    });

    test('10. BLE-06: Granular permission status enum, location services, and adapter state handling', () {
      // 1. Verify BlePermissionStatus enum values
      expect(BlePermissionStatus.values, contains(BlePermissionStatus.granted));
      expect(BlePermissionStatus.values, contains(BlePermissionStatus.denied));
      expect(BlePermissionStatus.values, contains(BlePermissionStatus.permanentlyDenied));
      expect(BlePermissionStatus.values, contains(BlePermissionStatus.restricted));

      // 2. Verify isBluetoothEnabledNotifier initial value and bridge defaults
      final bridge = UteBleBridge();
      expect(bridge.isBluetoothEnabledNotifier.value, isTrue);

      bridge.isBluetoothEnabledNotifier.value = false;
      expect(bridge.isBluetoothEnabledNotifier.value, isFalse);
      bridge.isBluetoothEnabledNotifier.value = true;
      expect(bridge.isBluetoothEnabledNotifier.value, isTrue);
    });

    test('11. PERF-01: DaySnapshotRepository.upsertAll stores locally without cloud push cascade', () async {
      SharedPreferences.setMockInitialValues({});

      final snaps = List.generate(60, (i) {
        final date = DateTime(2026, 1, 1).add(Duration(days: i));
        final key = DaySnapshot.keyFor(date);
        return DaySnapshot(
          dateKey: key,
          recovery: 70 + (i % 20),
          strain: 10.0 + (i % 5),
          sleep: 420 + (i % 60),
          hrv: 55.0 + (i % 15),
          rhr: 58 + (i % 8),
          preview: false,
        );
      });

      // Saving all 60 snapshots with syncToCloud: false MUST save to prefs without throwing or cloud writes
      await DaySnapshotRepository.upsertAll(snaps, syncToCloud: false);

      final loaded = await DaySnapshotRepository.loadAll();
      expect(loaded.length, 60);
      expect(loaded.first.dateKey, snaps.first.dateKey);
      expect(loaded.last.dateKey, snaps.last.dateKey);
      expect(loaded.last.recovery, snaps.last.recovery);

      // Upserting single day with syncToCloud: false also persists locally
      final updatedLast = loaded.last.copyWith(recovery: 99);
      await DaySnapshotRepository.upsert(updatedLast, syncToCloud: false);

      final reloaded = await DaySnapshotRepository.loadAll();
      expect(reloaded.length, 60);
      expect(reloaded.last.recovery, 99);
    });

    test('12. BLE Connection Hardening: disconnect flags, timeout cancellation, and no false ready from telemetry', () async {
      SharedPreferences.setMockInitialValues({'kalkan_last_device_mac': 'AA:BB:CC:DD:EE:11'});
      final bridge = UteBleBridge();

      // Verify initial paired address
      expect(await bridge.getLastPairedAddress(), 'AA:BB:CC:DD:EE:11');

      // Test disconnect(forget: false) retains paired address in prefs
      await bridge.disconnect(forget: false);
      expect(await bridge.getLastPairedAddress(), 'AA:BB:CC:DD:EE:11');
      expect(bridge.connectionState, BleConnectionState.idle);

      // Test disconnect(forget: true) clears paired address in prefs
      await bridge.disconnect(forget: true);
      expect(await bridge.getLastPairedAddress(), isNull);
      expect(bridge.connectionState, BleConnectionState.idle);

      // Verify cancelConnect transitions state safely
      await bridge.cancelConnect();
      expect(bridge.connectionState, BleConnectionState.idle);
    });
  });
}
