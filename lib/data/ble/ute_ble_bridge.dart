import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/telemetry.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/workout_session.dart';
import '../storage/user_profile_repository.dart';
import '../storage/workout_repository.dart';

/// Состояния конечного автомата подключения BLE (BLE-02)
enum BleConnectionState {
  idle,
  connecting,
  discovering,
  ready,
  backoff,
  failed,
}

/// Статус разрешений BLE (BLE-06)
enum BlePermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

BlePermissionStatus _parsePermissionStatus(dynamic status) {
  if (status == 'granted' || status == true) return BlePermissionStatus.granted;
  if (status == 'permanentlyDenied') return BlePermissionStatus.permanentlyDenied;
  if (status == 'restricted') return BlePermissionStatus.restricted;
  return BlePermissionStatus.denied;
}

class DiscoveredBleDevice {
  final String name;
  final String address;
  final int rssi;
  final bool isKalkanBand;

  const DiscoveredBleDevice({
    required this.name,
    required this.address,
    required this.rssi,
    this.isKalkanBand = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredBleDevice &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;
}

/// Одна точка пульсовой истории за день (реальные данные с часов)
class HeartRateSample {
  final DateTime timestamp;
  final int bpm;

  const HeartRateSample({required this.timestamp, required this.bpm});
}

/// Мост к нативному BLE SDK (UTE Nadal Android AAR + iOS CoreBluetooth Framework)
class UteBleBridge {
  static UteBleBridge? _instance;
  static UteBleBridge get instance => _instance ??= UteBleBridge._internal();

  factory UteBleBridge() => instance;

  UteBleBridge._internal();

  static const MethodChannel _methodChannel = MethodChannel('com.nadal.ble/methods');
  static const EventChannel _eventChannel = EventChannel('com.nadal.ble/telemetry');
  static const EventChannel _scanChannel = EventChannel('com.nadal.ble/scan');

  final StreamController<BleTelemetry> _telemetryController = StreamController.broadcast();
  final StreamController<List<DiscoveredBleDevice>> _scanController =
      StreamController<List<DiscoveredBleDevice>>.broadcast();

  final Map<String, DiscoveredBleDevice> _discoveredMap = {};
  StreamSubscription? _eventSub;
  StreamSubscription? _scanSub;
  BleTelemetry? _realTelemetry;

  BleConnectionState _connectionState = BleConnectionState.idle;
  final ValueNotifier<BleConnectionState> connectionStateNotifier =
      ValueNotifier<BleConnectionState>(BleConnectionState.idle);
  final ValueNotifier<bool> isBluetoothEnabledNotifier = ValueNotifier<bool>(true);

  BleConnectionState get connectionState => _connectionState;

  void _setConnectionState(BleConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      connectionStateNotifier.value = state;
      debugPrint('UteBleBridge: connectionState -> $state');
    }
  }

  bool _isConnecting = false;
  Completer<bool>? _connectCompleter;
  int _reconnectAttempts = 0;
  Timer? _backoffTimer;
  bool _isManuallyDisconnected = false;
  bool get isManuallyDisconnected => _isManuallyDisconnected;
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  Stream<BleTelemetry> get telemetryStream => _telemetryController.stream;
  Stream<List<DiscoveredBleDevice>> get scanResultsStream => _scanController.stream;
  List<DiscoveredBleDevice> get discoveredDevices =>
      _discoveredMap.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));

  BleTelemetry get currentTelemetry {
    return _realTelemetry ?? BleTelemetry.empty();
  }

  bool get isConnected => _realTelemetry?.isConnected == true && _connectionState == BleConnectionState.ready;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isManuallyDisconnected = prefs.getBool('kalkan_is_manually_disconnected') ?? false;
    } catch (_) {}

    try {
      _eventSub = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            if (event.containsKey('isBluetoothEnabled')) {
              final enabled = _parseBool(event['isBluetoothEnabled'], true);
              if (isBluetoothEnabledNotifier.value != enabled) {
                isBluetoothEnabledNotifier.value = enabled;
              }
            }
            final isConnected = _parseBool(event['isConnected'], false);
            final prev = _realTelemetry;

            final telemetry = BleTelemetry(
              heartRate: _parseInt(event['heartRate'], prev?.heartRate ?? 0),
              steps: _parseInt(event['steps'], prev?.steps ?? 0),
              calories: _parseInt(event['calories'], prev?.calories ?? 0),
              batteryLevel: _parseInt(event['batteryLevel'], prev?.batteryLevel ?? 0),
              isCharging: _parseBool(event['isCharging'], prev?.isCharging ?? false),
              isConnected: isConnected,
              deviceName: event['deviceName']?.toString() ?? (isConnected ? 'KALKAN СААТ-1' : (prev?.deviceName ?? 'СААТ-1')),
              timestamp: DateTime.now(),
              lastSyncAt: isConnected ? DateTime.now() : (prev?.lastSyncAt ?? prev?.timestamp),
              hrv: _parseDouble(event['hrv'], prev?.hrv ?? 0.0),
              restingHeartRate: _parseInt(event['restingHeartRate'], prev?.restingHeartRate ?? 0),
              respiratoryRate: _parseDouble(event['respiratoryRate'], prev?.respiratoryRate ?? 0.0),
              skinTempDeviation: _parseDouble(event['skinTempDeviation'], prev?.skinTempDeviation ?? 0.0),
              isOffWrist: _parseBool(event['isOffWrist'], prev?.isOffWrist ?? false),
              sleepMinutes: _parseInt(event['sleepMinutes'], prev?.sleepMinutes ?? 0),
              deepSleepMinutes: _parseInt(event['deepSleepMinutes'], prev?.deepSleepMinutes ?? 0),
              remSleepMinutes: _parseInt(event['remSleepMinutes'], prev?.remSleepMinutes ?? 0),
              timeInBedMinutes: _parseInt(event['timeInBedMinutes'], prev?.timeInBedMinutes ?? 0),
              sleepEfficiency: _parseDouble(event['sleepEfficiency'], prev?.sleepEfficiency ?? 0.0),
              sleepConsistency: _parseDouble(event['sleepConsistency'], prev?.sleepConsistency ?? 0.0),
              restorativeSleepRatio: _parseDouble(event['restorativeSleepRatio'], prev?.restorativeSleepRatio ?? 0.0),
              sleepHypnogram: _parseSleepHypnogram(event['sleepHypnogram']) ?? prev?.sleepHypnogram ?? const [],
              currentDayStrain: _parseDouble(event['currentDayStrain'], prev?.currentDayStrain ?? 0.0),
              yesterdayStrain: _parseDouble(event['yesterdayStrain'], prev?.yesterdayStrain ?? 0.0),
              zoneMinutes: _parseZoneMinutes(event['zoneMinutes']) ?? prev?.zoneMinutes ?? const [0, 0, 0, 0, 0],
              currentStressScore: _parseInt(event['currentStressScore'], prev?.currentStressScore ?? 0),
              bloodOxygen: _parseInt(event['bloodOxygen'], prev?.bloodOxygen ?? 0),
              isAncsAuthorized: _parseBool(event['isAncsAuthorized'], prev?.isAncsAuthorized ?? true),
            );

            _realTelemetry = telemetry;
            _telemetryController.add(telemetry);

            if (isConnected) {
              _setConnectionState(BleConnectionState.ready);
              _reconnectAttempts = 0;
            } else if (_connectionState == BleConnectionState.ready) {
              _setConnectionState(BleConnectionState.idle);
              if (!_isManuallyDisconnected) {
                // Connection dropped involuntarily: schedule backoff reconnect
                getLastPairedAddress().then((lastMac) {
                  if (lastMac != null && lastMac.isNotEmpty && !_isManuallyDisconnected) {
                    _scheduleBackoffReconnect(lastMac);
                  }
                });
              }
            }
          }
        },
        onError: (err) {
          debugPrint('UteBleBridge telemetry stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('UteBleBridge init stream error: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMac = prefs.getString('kalkan_last_device_mac');
      if (lastMac != null && lastMac.isNotEmpty && !_isManuallyDisconnected) {
        checkAndReconnect();
      }
    } catch (e) {
      debugPrint('UteBleBridge auto-connect error: $e');
    }
  }

  // --- Проверка Bluetooth и разрешений ---

  Future<bool> isBluetoothEnabled() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('isBluetoothEnabled');
      final val = res ?? false;
      if (isBluetoothEnabledNotifier.value != val) {
        isBluetoothEnabledNotifier.value = val;
      }
      return val;
    } catch (e) {
      debugPrint('UteBleBridge isBluetoothEnabled error: $e');
      return false;
    }
  }

  Future<bool> isLocationServiceEnabled() async {
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    try {
      final res = await _methodChannel.invokeMethod<bool>('isLocationServiceEnabled');
      return res ?? isIos;
    } catch (e) {
      debugPrint('UteBleBridge isLocationServiceEnabled error: $e');
      return isIos;
    }
  }

  Future<bool> openAppSettings() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('openAppSettings');
      return res ?? false;
    } catch (e) {
      debugPrint('UteBleBridge openAppSettings error: $e');
      return false;
    }
  }

  Future<bool> openLocationSettings() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('openLocationSettings');
      return res ?? false;
    } catch (e) {
      debugPrint('UteBleBridge openLocationSettings error: $e');
      return false;
    }
  }

  Future<BlePermissionStatus> checkPermissionStatus() async {
    try {
      final res = await _methodChannel.invokeMethod<dynamic>('checkPermissions');
      return _parsePermissionStatus(res);
    } catch (e) {
      debugPrint('UteBleBridge checkPermissionStatus error: $e');
      return BlePermissionStatus.denied;
    }
  }

  Future<BlePermissionStatus> requestPermissionStatus() async {
    try {
      final res = await _methodChannel.invokeMethod<dynamic>('requestPermissions');
      return _parsePermissionStatus(res);
    } catch (e) {
      debugPrint('UteBleBridge requestPermissionStatus error: $e');
      return BlePermissionStatus.denied;
    }
  }

  Future<bool> checkPermissions() async {
    final status = await checkPermissionStatus();
    return status == BlePermissionStatus.granted;
  }

  Future<bool> requestPermissions() async {
    final status = await requestPermissionStatus();
    return status == BlePermissionStatus.granted;
  }

  // --- Сканирование и обнаружение устройств ---

  static final RegExp _uteWordRegex = RegExp(r'(^|[\s\-_])ute([\s\-_0-9]|$)', caseSensitive: false);

  static bool matchesKalkanFilter(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.isEmpty || lower == 'unknown' || lower == 'ble устройство') return false;
    return lower.contains('kalkan') ||
        lower.contains('саат') ||
        lower.contains('saat') ||
        lower.contains('nadal') ||
        _uteWordRegex.hasMatch(lower);
  }

  Future<void> startScan() async {
    if (_isScanning) {
      debugPrint('UteBleBridge startScan skipped: scan already in progress');
      return;
    }
    _isScanning = true;
    _discoveredMap.clear();
    _scanController.add([]);

    _scanSub?.cancel();
    try {
      _scanSub = _scanChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            if (_parseBool(event['isScanComplete'], false)) {
              _isScanning = false;
              return;
            }
            final name = event['name']?.toString() ?? 'BLE Устройство';
            final address = event['address']?.toString() ?? '';
            final rssi = _parseInt(event['rssi'], -70);
            final isKalkan = _parseBool(event['isKalkan'], false) || matchesKalkanFilter(name);

            if (address.isNotEmpty) {
              if (_discoveredMap.length >= 100 && !_discoveredMap.containsKey(address)) {
                return;
              }
              _discoveredMap[address] = DiscoveredBleDevice(
                name: name,
                address: address,
                rssi: rssi,
                isKalkanBand: isKalkan,
              );
              final sorted = _discoveredMap.values.toList()
                ..sort((a, b) {
                  if (a.isKalkanBand != b.isKalkanBand) {
                    return a.isKalkanBand ? -1 : 1;
                  }
                  return b.rssi.compareTo(a.rssi);
                });
              _scanController.add(sorted);
            }
          }
        },
        onError: (Object err) {
          _isScanning = false;
          debugPrint('UteBleBridge scanChannel error: $err');
        },
        onDone: () {
          _isScanning = false;
        },
      );

      await _methodChannel.invokeMethod('startScan');
    } catch (e) {
      _isScanning = false;
      debugPrint('UteBleBridge startScan error: $e');
    }
  }

  Future<void> stopScan() async {
    _isScanning = false;
    try {
      await _methodChannel.invokeMethod('stopScan');
    } catch (e) {
      debugPrint('UteBleBridge stopScan error: $e');
    }
    _scanSub?.cancel();
  }

  // --- Управление подключением (BLE-02: статус-машина, таймаут 15с, бэкофф) ---

  /// Подключение к часам с явной статус-машиной и таймаутом 15 секунд.
  /// MAC-адрес сохраняется в SharedPreferences ТОЛЬКО после подтверждения готовности (ready).
  Future<bool> connect(String macAddress, {Duration timeout = const Duration(seconds: 15)}) async {
    final trimmedMac = macAddress.trim();
    if (trimmedMac.isEmpty) return false;

    // Останавливаем активный скан перед подключением
    await stopScan();

    // Reset manual disconnect flag on explicit connect
    _isManuallyDisconnected = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('kalkan_is_manually_disconnected', false);
    } catch (_) {}

    // Guard от повторного входа: если уже подключены к этому устройству
    if (_realTelemetry?.isConnected == true && _connectionState == BleConnectionState.ready) {
      final lastMac = await getLastPairedAddress();
      if (lastMac == trimmedMac) {
        return true;
      }
      // Подключены к другому устройству: сначала разрываем старое соединение
      await disconnect(forget: false, markManual: false);
    }

    // Если подключение уже в процессе — ожидаем завершения текущего
    if (_isConnecting && _connectCompleter != null) {
      return _connectCompleter!.future;
    }

    final btEnabled = await isBluetoothEnabled();
    if (!btEnabled) {
      debugPrint('UteBleBridge.connect: aborted because Bluetooth is disabled');
      _setConnectionState(BleConnectionState.failed);
      return false;
    }
    final permStatus = await checkPermissionStatus();
    if (permStatus != BlePermissionStatus.granted) {
      debugPrint('UteBleBridge.connect: aborted because permissions not granted ($permStatus)');
      _setConnectionState(BleConnectionState.failed);
      return false;
    }

    _isConnecting = true;
    _setConnectionState(BleConnectionState.connecting);
    final completer = Completer<bool>();
    _connectCompleter = completer;

    // Сбрасываем бэкофф-таймер перед новой явной попыткой
    _backoffTimer?.cancel();
    _backoffTimer = null;

    Timer? timeoutTimer;
    bool isCompleted = false;

    void finishConnect(bool success) async {
      if (isCompleted) return;
      isCompleted = true;
      timeoutTimer?.cancel();
      timeoutTimer = null;
      _isConnecting = false;

      if (success) {
        _setConnectionState(BleConnectionState.ready);
        _reconnectAttempts = 0;
        unawaited(syncUserProfile());
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('kalkan_last_device_mac', trimmedMac);
        } catch (e) {
          debugPrint('UteBleBridge: error saving MAC to prefs: $e');
        }
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      } else {
        _setConnectionState(BleConnectionState.failed);
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      }
    }

    timeoutTimer = Timer(timeout, () async {
      debugPrint('UteBleBridge.connect: timeout after ${timeout.inSeconds}s for $trimmedMac');
      // Таймаут в Dart: обязательно отменяем нативную попытку подключения!
      try {
        await _methodChannel.invokeMethod('cancelConnect');
      } catch (_) {
        try {
          await _methodChannel.invokeMethod('disconnect', {'forget': false});
        } catch (_) {}
      }
      finishConnect(false);
    });

    try {
      final res = await _methodChannel.invokeMethod<bool>('connect', {'address': trimmedMac});
      if (res == true) {
        finishConnect(true);
      } else {
        finishConnect(false);
      }
    } catch (e) {
      debugPrint('UteBleBridge connect error: $e');
      finishConnect(false);
    }

    return completer.future;
  }

  Future<void> cancelConnect() async {
    _backoffTimer?.cancel();
    _backoffTimer = null;
    if (_isConnecting) {
      try {
        await _methodChannel.invokeMethod('cancelConnect');
      } catch (_) {
        try {
          await _methodChannel.invokeMethod('disconnect', {'forget': false});
        } catch (_) {}
      }
      _isConnecting = false;
      _setConnectionState(BleConnectionState.idle);
      if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
        _connectCompleter!.complete(false);
      }
    }
  }

  Future<void> disconnect({bool forget = false, bool markManual = true}) async {
    if (markManual) {
      _isManuallyDisconnected = true;
    }
    _backoffTimer?.cancel();
    _backoffTimer = null;
    _reconnectAttempts = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (markManual) {
        await prefs.setBool('kalkan_is_manually_disconnected', true);
      }
      if (forget) {
        await prefs.remove('kalkan_last_device_mac');
      }
      await _methodChannel.invokeMethod('disconnect', {'forget': forget});
    } catch (e) {
      debugPrint('UteBleBridge disconnect error: $e');
    }
    _setConnectionState(BleConnectionState.idle);
    if (_realTelemetry != null) {
      if (forget) {
        _realTelemetry = BleTelemetry.empty();
      } else {
        _realTelemetry = _realTelemetry!.copyWith(
          isConnected: false,
          isCharging: false,
          heartRate: 0,
          isOffWrist: false,
          skinTempDeviation: 0.0,
        );
      }
      _telemetryController.add(_realTelemetry!);
    }
  }

  Future<bool> resetToFactorySettings() async {
    try {
      await _methodChannel.invokeMethod('resetFactory');
    } catch (e) {
      debugPrint('UteBleBridge resetToFactorySettings error: $e');
    }
    await disconnect(forget: true);
    return true;
  }

  Future<void> configureHeartRateMonitoring({int intervalMinutes = 15, bool continuous = false}) async {
    try {
      await _methodChannel.invokeMethod('configureHeartRateMonitoring', {
        'intervalMinutes': intervalMinutes,
        'continuous': continuous,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('kalkan_hr_interval_minutes', intervalMinutes);
      await prefs.setBool('kalkan_hr_continuous_enabled', continuous);
    } catch (e) {
      debugPrint('UteBleBridge configureHeartRateMonitoring error: $e');
    }
  }

  Future<void> setDisconnectRemind(bool enable) async {
    try {
      await _methodChannel.invokeMethod('setDisconnectRemind', {'enable': enable});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('kalkan_disconnect_alert_enabled', enable);
    } catch (e) {
      debugPrint('UteBleBridge setDisconnectRemind error: $e');
    }
  }

  Future<void> setSmartAlarm(bool enable, {int hour = 7, int minute = 0}) async {
    try {
      await _methodChannel.invokeMethod('setSmartAlarm', {
        'enable': enable,
        'hour': hour,
        'minute': minute,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('kalkan_smart_alarm_enabled', enable);
    } catch (e) {
      debugPrint('UteBleBridge setSmartAlarm error: $e');
    }
  }

  Future<void> setHydrationReminder(bool enable, {int intervalMinutes = 120}) async {
    try {
      await _methodChannel.invokeMethod('setHydrationReminder', {
        'enable': enable,
        'intervalMinutes': intervalMinutes,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('kalkan_hydration_reminder_enabled', enable);
    } catch (e) {
      debugPrint('UteBleBridge setHydrationReminder error: $e');
    }
  }

  Future<void> clearAccountData() async {
    try {
      await _methodChannel.invokeMethod('clearAccountData');
    } catch (e) {
      debugPrint('UteBleBridge clearAccountData error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> syncWorkoutHistory() async {
    try {
      final res = await _methodChannel.invokeListMethod<dynamic>('getWorkoutHistory');
      if (res != null && res.isNotEmpty) {
        final list = <Map<String, dynamic>>[];
        for (final item in res) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            list.add(m);
            await _persistWatchWorkout(m);
          }
        }
        return list;
      }
    } catch (e) {
      debugPrint('UteBleBridge syncWorkoutHistory error: $e');
    }
    return [];
  }

  Future<bool> pullNightAndDay() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('pullNightAndDay');
      return res ?? false;
    } catch (e) {
      debugPrint('UteBleBridge pullNightAndDay error: $e');
      return false;
    }
  }

  Future<bool> syncUserProfile([UserProfile? profile]) async {
    try {
      final p = profile ?? UserProfileRepository.profileNotifier.value;
      final birthYear = p.birthYear > 1900 ? p.birthYear : 1996;
      final age = (DateTime.now().year - birthYear).clamp(10, 100);
      final res = await _methodChannel.invokeMethod<bool>('setUserProfile', {
        'heightCm': p.heightCm.round(),
        'weightKg': p.weightKg.round(),
        'age': age,
        'gender': p.gender.name,
        'stepGoal': p.stepGoal,
        'calorieGoal': p.calorieGoal,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('UteBleBridge syncUserProfile error: $e');
      return false;
    }
  }

  static DateTime _parseVendorDateTime(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is num) {
      final n = raw.toInt();
      if (n > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(n);
      if (n > 1000000) return DateTime.fromMillisecondsSinceEpoch(n * 1000);
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return DateTime.now();

    final asNum = int.tryParse(s);
    if (asNum != null) {
      if (asNum > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(asNum);
      if (asNum > 1000000) return DateTime.fromMillisecondsSinceEpoch(asNum * 1000);
    }

    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;

    try {
      final parts = s.replaceAll('/', '-').replaceAll(':', '-').replaceAll(' ', '-').split('-');
      if (parts.length >= 3) {
        final year = int.tryParse(parts[0]) ?? DateTime.now().year;
        final month = int.tryParse(parts[1]) ?? 1;
        final day = int.tryParse(parts[2]) ?? 1;
        final hour = parts.length > 3 ? (int.tryParse(parts[3]) ?? 0) : 0;
        final min = parts.length > 4 ? (int.tryParse(parts[4]) ?? 0) : 0;
        final sec = parts.length > 5 ? (int.tryParse(parts[5]) ?? 0) : 0;
        return DateTime(year, month, day, hour, min, sec);
      }
    } catch (_) {}

    return DateTime.now();
  }

  Future<void> _persistWatchWorkout(Map<String, dynamic> data) async {
    try {
      final startedAt = _parseVendorDateTime(data['startTime']);

      final durationSec = (data['duration'] as num?)?.toInt() ?? 0;
      if (durationSec < 60) return; // Игнорируем случайные включения короче 1 минуты

      final id = 'watch_${startedAt.millisecondsSinceEpoch}';
      final existing = await WorkoutRepository.loadWorkouts();
      if (existing.any((w) => w.id == id || (w.startedAt.difference(startedAt).inMinutes.abs() < 2 && w.externalSource == 'watch'))) {
        return;
      }

      final rawSportsType = (data['sportsType'] as num?)?.toInt() ?? 0;
      final sport = _mapUteSportType(rawSportsType);
      final calories = (data['calories'] as num?)?.toInt() ?? 0;
      final distanceM = (data['distance'] as num?)?.toDouble() ?? 0.0;
      final steps = (data['steps'] as num?)?.toInt() ?? 0;
      final avgHr = (data['heart'] as num?)?.toInt() ?? 0;
      final maxHr = (data['maxHeart'] as num?)?.toInt() ?? 0;

      double strain = 0.0;
      if (avgHr > 60 && durationSec > 0) {
        strain = ((avgHr - 60) / 130.0 * (durationSec / 3600.0) * 12.0).clamp(1.0, 19.5);
        strain = double.parse(strain.toStringAsFixed(1));
      }

      final workout = CompletedWorkout(
        id: id,
        sport: sport,
        startedAt: startedAt,
        durationSeconds: durationSec,
        calories: calories,
        distanceKm: distanceM > 0 ? (distanceM / 1000.0) : 0.0,
        avgHr: avgHr,
        maxHr: maxHr,
        strain: strain,
        xpEarned: (durationSec ~/ 60) * 10,
        steps: steps,
        externalSource: 'watch',
        sourceAppName: 'KALKAN СААТ-1',
      );

      await WorkoutRepository.saveWorkout(workout);
    } catch (e) {
      debugPrint('UteBleBridge _persistWatchWorkout error: $e');
    }
  }

  SportType _mapUteSportType(int type) {
    switch (type) {
      case 1:
        return SportType.walkOutdoor;
      case 2:
        return SportType.cycling;
      case 3:
        return SportType.swimming;
      case 4:
        return SportType.runIndoor;
      case 5:
        return SportType.strength;
      case 6:
        return SportType.hiit;
      case 7:
        return SportType.yoga;
      default:
        return SportType.runOutdoor;
    }
  }

  Future<void> setCallRemindEnable(bool enable) async {
    try {
      await _methodChannel.invokeMethod('setCallRemindEnable', {'enable': enable});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('kalkan_call_remind_enabled', enable);
    } catch (e) {
      debugPrint('UteBleBridge setCallRemindEnable error: $e');
    }
  }

  Future<bool> isNotificationListenerGranted() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('isNotificationListenerGranted');
      return res ?? false;
    } catch (e) {
      debugPrint('UteBleBridge isNotificationListenerGranted error: $e');
      return false;
    }
  }

  Future<void> openNotificationListenerSettings() async {
    try {
      await _methodChannel.invokeMethod('openNotificationListenerSettings');
    } catch (e) {
      debugPrint('UteBleBridge openNotificationListenerSettings error: $e');
    }
  }

  Future<String?> getLastPairedAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('kalkan_last_device_mac');
    } catch (e) {
      debugPrint('UteBleBridge getLastPairedAddress error: $e');
      return null;
    }
  }

  Future<void> checkAndReconnect() async {
    if (_isConnecting) return;
    if (_isManuallyDisconnected) {
      debugPrint('UteBleBridge: auto-reconnect skipped because user manually disconnected');
      return;
    }
    if (_realTelemetry?.isConnected == true) return;
    if (_connectionState == BleConnectionState.connecting || _connectionState == BleConnectionState.discovering) return;

    final btEnabled = await isBluetoothEnabled();
    if (!btEnabled) {
      debugPrint('UteBleBridge: auto-reconnect skipped because Bluetooth is disabled');
      return;
    }
    final permStatus = await checkPermissionStatus();
    if (permStatus != BlePermissionStatus.granted) {
      debugPrint('UteBleBridge: auto-reconnect skipped because permissions not granted ($permStatus)');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final isManual = prefs.getBool('kalkan_is_manually_disconnected') ?? false;
      if (isManual) {
        _isManuallyDisconnected = true;
        debugPrint('UteBleBridge: auto-reconnect skipped because user manually disconnected (prefs)');
        return;
      }
      final lastMac = prefs.getString('kalkan_last_device_mac');
      if (lastMac != null && lastMac.isNotEmpty) {
        debugPrint('UteBleBridge: auto-reconnecting to $lastMac (attempt $_reconnectAttempts)');
        final ok = await connect(lastMac);
        if (!ok && _realTelemetry?.isConnected != true && !_isManuallyDisconnected) {
          _scheduleBackoffReconnect(lastMac);
        }
      }
    } catch (e) {
      debugPrint('UteBleBridge checkAndReconnect error: $e');
    }
  }

  void _scheduleBackoffReconnect(String macAddress) {
    if (_isManuallyDisconnected) return;
    _backoffTimer?.cancel();
    _reconnectAttempts++;
    // Экспоненциальный бэкофф с джиттером: 2 -> 4 -> 8 -> 16 -> 32 -> 60s
    final baseSeconds = (2 * (1 << math.min(_reconnectAttempts - 1, 5))).clamp(2, 60);
    final jitter = math.Random().nextDouble() * 1.5;
    final delaySeconds = (baseSeconds + jitter).clamp(2.0, 60.0);

    _setConnectionState(BleConnectionState.backoff);
    debugPrint('UteBleBridge: scheduling backoff reconnect in ${delaySeconds.toStringAsFixed(1)}s (attempt $_reconnectAttempts)');

    _backoffTimer = Timer(Duration(milliseconds: (delaySeconds * 1000).toInt()), () async {
      if (_realTelemetry?.isConnected == true || _isConnecting || _isManuallyDisconnected) return;
      final ok = await connect(macAddress);
      if (!ok && _realTelemetry?.isConnected != true && !_isManuallyDisconnected) {
        _scheduleBackoffReconnect(macAddress);
      }
    });
  }

  // --- Команды часам ---

  Future<void> findWatch({bool enable = true}) async {
    try {
      await _methodChannel.invokeMethod('findDevice', {'enable': enable});
    } catch (e) {
      debugPrint('UteBleBridge findWatch error: $e');
    }
  }

  Future<void> syncTime() async {
    try {
      await _methodChannel.invokeMethod('syncTime');
    } catch (e) {
      debugPrint('UteBleBridge syncTime error: $e');
    }
  }

  Future<void> triggerHeartRateMeasurement() async {
    try {
      await _methodChannel.invokeMethod('measureHeartRate');
    } catch (e) {
      debugPrint('UteBleBridge triggerHeartRateMeasurement error: $e');
    }
  }

  /// Выгружает поминутную пульсовую историю за последние 24 часа с часов (если подключены).
  Future<List<HeartRateSample>> fetchHeartRateHistory() async {
    try {
      final raw = await _methodChannel.invokeMethod<List<dynamic>>('getHeartRateHistory');
      if (raw == null) return const [];
      final out = <HeartRateSample>[];
      for (final e in raw) {
        if (e is Map) {
          final t = _parseInt(e['t']);
          final bpm = _parseInt(e['bpm']);
          if (t > 0 && bpm > 0) {
            out.add(HeartRateSample(
              timestamp: DateTime.fromMillisecondsSinceEpoch(t),
              bpm: bpm,
            ));
          }
        }
      }
      out.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return out;
    } catch (e) {
      debugPrint('UteBleBridge fetchHeartRateHistory error: $e');
      return const [];
    }
  }
  static bool _parseBool(dynamic val, [bool fallback = false]) {
    if (val == null) return fallback;
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) {
      final s = val.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return fallback;
  }

  static int _parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  static double _parseDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }

  static List<int>? _parseZoneMinutes(dynamic raw) {
    if (raw is! List) return null;
    final out = <int>[];
    for (final e in raw) {
      final int? n;
      if (e is num) {
        n = e.round();
      } else if (e is String) {
        n = int.tryParse(e.trim());
      } else {
        n = null;
      }
      if (n == null) return null;
      out.add(n);
    }
    if (out.length < 5) return null;
    return out.take(5).toList();
  }

  static List<SleepEpoch>? _parseSleepHypnogram(dynamic raw) {
    if (raw is! List) return null;
    final epochs = <SleepEpoch>[];
    for (final item in raw) {
      if (item is Map) {
        final stageStr = item['stage']?.toString().toLowerCase();
        SleepStageType stage;
        switch (stageStr) {
          case 'deep':
            stage = SleepStageType.deep;
            break;
          case 'rem':
            stage = SleepStageType.rem;
            break;
          case 'light':
            stage = SleepStageType.light;
            break;
          case 'awake':
          default:
            stage = SleepStageType.awake;
            break;
        }
        final startMs = _parseInt(item['startTime'] ?? item['startTs']);
        final endMs = _parseInt(item['endTime'] ?? item['endTs']);
        if (startMs > 0 && endMs > startMs) {
          epochs.add(SleepEpoch(
            startTime: DateTime.fromMillisecondsSinceEpoch(startMs),
            endTime: DateTime.fromMillisecondsSinceEpoch(endMs),
            stage: stage,
          ));
        }
      }
    }
    return epochs.isEmpty ? null : epochs;
  }

  void dispose() {
    _scanSub?.cancel();
    _eventSub?.cancel();
    _scanController.close();
    _telemetryController.close();
  }
}
