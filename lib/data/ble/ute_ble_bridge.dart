import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/telemetry.dart';

class DiscoveredBleDevice {
  final String name;
  final String address;
  final int rssi;

  const DiscoveredBleDevice({
    required this.name,
    required this.address,
    required this.rssi,
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
        connect(lastMac);
      }
    } catch (e) {
      debugPrint('UteBleBridge auto-connect error: $e');
    }
  }

  // --- Проверка Bluetooth и разрешений ---

  Future<bool> isBluetoothEnabled() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('isBluetoothEnabled');
      return res ?? false;
    } catch (e) {
      debugPrint('UteBleBridge isBluetoothEnabled error: $e');
      return false;
    }
  }

  Future<bool> checkPermissions() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('checkPermissions');
      return res ?? false;
    } catch (e) {
      debugPrint('UteBleBridge checkPermissions error: $e');
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('requestPermissions');
      return res ?? false;
    } catch (e) {
      debugPrint('UteBleBridge requestPermissions error: $e');
      return false;
    }
  }

  // --- Сканирование и обнаружение устройств ---

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
          final name = event['name']?.toString() ?? 'Unknown';
          final address = event['address']?.toString() ?? '';
          final rssi = _parseInt(event['rssi'], -70);
          if (rssi < -85 && rssi != 0) return;

          if (address.isNotEmpty) {
            if (_discoveredMap.length >= 25 && !_discoveredMap.containsKey(address)) {
              return;
            }
            _discoveredMap[address] = DiscoveredBleDevice(
              name: name,
              address: address,
              rssi: rssi,
            );
            final sorted = _discoveredMap.values.toList()
              ..sort((a, b) => b.rssi.compareTo(a.rssi));
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

  // --- Управление подключением ---

  Future<void> connect(String macAddress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kalkan_last_device_mac', macAddress);
      await _methodChannel.invokeMethod('connect', {'address': macAddress});
    } catch (e) {
      debugPrint('UteBleBridge connect error: $e');
    }
  }

  Future<void> disconnect({bool forget = false}) async {
    try {
      if (forget) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('kalkan_last_device_mac');
      }
      await _methodChannel.invokeMethod('disconnect');
    } catch (e) {
      debugPrint('UteBleBridge disconnect error: $e');
    }
    if (_realTelemetry != null) {
      _realTelemetry = _realTelemetry!.copyWith(isConnected: false, isCharging: false);
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
    try {
      if (_realTelemetry?.isConnected == true) return;
      final prefs = await SharedPreferences.getInstance();
      final lastMac = prefs.getString('kalkan_last_device_mac');
      if (lastMac != null && lastMac.isNotEmpty) {
        debugPrint('UteBleBridge: auto-reconnecting to $lastMac');
        await connect(lastMac);
      }
    } catch (e) {
      debugPrint('UteBleBridge checkAndReconnect error: $e');
    }
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
