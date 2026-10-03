import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/telemetry.dart';

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

/// Мост к нативному BLE SDK (UTE Nadal Android AAR + iOS CoreBluetooth Framework)
class UteBleBridge {
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

  Stream<BleTelemetry> get telemetryStream => _telemetryController.stream;
  Stream<List<DiscoveredBleDevice>> get scanResultsStream => _scanController.stream;
  List<DiscoveredBleDevice> get discoveredDevices =>
      _discoveredMap.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));

  BleTelemetry get currentTelemetry {
    return _realTelemetry ?? BleTelemetry.empty();
  }

  Future<void> init() async {
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
            );

            _realTelemetry = telemetry;
            _telemetryController.add(telemetry);

            if (isConnected) {
              _setConnectionState(BleConnectionState.ready);
              _reconnectAttempts = 0;
            } else if (_connectionState == BleConnectionState.ready) {
              _setConnectionState(BleConnectionState.idle);
              checkAndReconnect();
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
      if (lastMac != null && lastMac.isNotEmpty) {
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
    try {
      final res = await _methodChannel.invokeMethod<bool>('isLocationServiceEnabled');
      return res ?? true;
    } catch (e) {
      debugPrint('UteBleBridge isLocationServiceEnabled error: $e');
      return true;
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
    _discoveredMap.clear();
    _scanController.add([]);

    _scanSub?.cancel();
    try {
      _scanSub = _scanChannel.receiveBroadcastStream().listen((dynamic event) {
        if (event is Map) {
          if (_parseBool(event['isScanComplete'], false)) {
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
      });

      await _methodChannel.invokeMethod('startScan');
    } catch (e) {
      debugPrint('UteBleBridge startScan error: $e');
    }
  }

  Future<void> stopScan() async {
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

    // Guard от повторного входа: если уже подключены к этому устройству
    if (_realTelemetry?.isConnected == true && _connectionState == BleConnectionState.ready) {
      final lastMac = await getLastPairedAddress();
      if (lastMac == trimmedMac) {
        return true;
      }
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
    StreamSubscription<BleTelemetry>? readySub;

    void finishConnect(bool success) async {
      timeoutTimer?.cancel();
      await readySub?.cancel();
      _isConnecting = false;

      if (success) {
        _setConnectionState(BleConnectionState.ready);
        _reconnectAttempts = 0;
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

    timeoutTimer = Timer(timeout, () {
      debugPrint('UteBleBridge.connect: timeout after ${timeout.inSeconds}s for $trimmedMac');
      finishConnect(false);
    });

    readySub = telemetryStream.listen((t) {
      if (t.isConnected) {
        finishConnect(true);
      }
    });

    try {
      final res = await _methodChannel.invokeMethod<bool>('connect', {'address': trimmedMac});
      if (res == false) {
        finishConnect(false);
      }
    } catch (e) {
      debugPrint('UteBleBridge connect error: $e');
      finishConnect(false);
    }

    return completer.future;
  }

  Future<void> disconnect({bool forget = false}) async {
    _backoffTimer?.cancel();
    _backoffTimer = null;
    _reconnectAttempts = 0;
    try {
      if (forget) {
        final prefs = await SharedPreferences.getInstance();
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
      final lastMac = prefs.getString('kalkan_last_device_mac');
      if (lastMac != null && lastMac.isNotEmpty) {
        debugPrint('UteBleBridge: auto-reconnecting to $lastMac (attempt $_reconnectAttempts)');
        final ok = await connect(lastMac);
        if (!ok && _realTelemetry?.isConnected != true) {
          _scheduleBackoffReconnect(lastMac);
        }
      }
    } catch (e) {
      debugPrint('UteBleBridge checkAndReconnect error: $e');
    }
  }

  void _scheduleBackoffReconnect(String macAddress) {
    _backoffTimer?.cancel();
    _reconnectAttempts++;
    // Экспоненциальный бэкофф с джиттером: 2 -> 4 -> 8 -> 16 -> 32 -> 60s
    final baseSeconds = (2 * (1 << math.min(_reconnectAttempts - 1, 5))).clamp(2, 60);
    final jitter = math.Random().nextDouble() * 1.5;
    final delaySeconds = (baseSeconds + jitter).clamp(2.0, 60.0);

    _setConnectionState(BleConnectionState.backoff);
    debugPrint('UteBleBridge: scheduling backoff reconnect in ${delaySeconds.toStringAsFixed(1)}s (attempt $_reconnectAttempts)');

    _backoffTimer = Timer(Duration(milliseconds: (delaySeconds * 1000).toInt()), () async {
      if (_realTelemetry?.isConnected == true || _isConnecting) return;
      final ok = await connect(macAddress);
      if (!ok && _realTelemetry?.isConnected != true) {
        _scheduleBackoffReconnect(macAddress);
      }
    });
  }

  // --- Команды часам ---

  Future<void> findWatch() async {
    try {
      await _methodChannel.invokeMethod('findDevice');
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
    final out = raw.map((e) => (e as num).round()).toList();
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
