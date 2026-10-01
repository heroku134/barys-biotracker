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
            final isConnected = event['isConnected'] as bool? ?? false;
            final prev = _realTelemetry;

            final telemetry = BleTelemetry(
              heartRate: event['heartRate'] as int? ?? prev?.heartRate ?? 0,
              steps: event['steps'] as int? ?? prev?.steps ?? 0,
              calories: event['calories'] as int? ?? prev?.calories ?? 0,
              batteryLevel: event['batteryLevel'] as int? ?? prev?.batteryLevel ?? 0,
              isCharging: event['isCharging'] as bool? ?? prev?.isCharging ?? false,
              isConnected: isConnected,
              deviceName: event['deviceName'] as String? ?? (isConnected ? 'KALKAN СААТ-1' : (prev?.deviceName ?? 'СААТ-1')),
              timestamp: DateTime.now(),
              hrv: (event['hrv'] as num?)?.toDouble() ?? prev?.hrv ?? 0,
              restingHeartRate: event['restingHeartRate'] as int? ?? prev?.restingHeartRate ?? 0,
              respiratoryRate: (event['respiratoryRate'] as num?)?.toDouble() ?? prev?.respiratoryRate ?? 0,
              skinTempDeviation: (event['skinTempDeviation'] as num?)?.toDouble() ?? prev?.skinTempDeviation ?? 0,
              isOffWrist: event['isOffWrist'] as bool? ?? prev?.isOffWrist ?? false,
              sleepMinutes: event['sleepMinutes'] as int? ?? prev?.sleepMinutes ?? 0,
              deepSleepMinutes: event['deepSleepMinutes'] as int? ?? prev?.deepSleepMinutes ?? 0,
              remSleepMinutes: event['remSleepMinutes'] as int? ?? prev?.remSleepMinutes ?? 0,
              timeInBedMinutes: event['timeInBedMinutes'] as int? ?? prev?.timeInBedMinutes ?? 0,
              sleepEfficiency: (event['sleepEfficiency'] as num?)?.toDouble() ?? prev?.sleepEfficiency ?? 0,
              sleepConsistency: (event['sleepConsistency'] as num?)?.toDouble() ?? prev?.sleepConsistency ?? 0,
              restorativeSleepRatio: (event['restorativeSleepRatio'] as num?)?.toDouble() ?? prev?.restorativeSleepRatio ?? 0,
              currentDayStrain: (event['currentDayStrain'] as num?)?.toDouble() ?? prev?.currentDayStrain ?? 0,
              yesterdayStrain: (event['yesterdayStrain'] as num?)?.toDouble() ?? prev?.yesterdayStrain ?? 0,
              zoneMinutes: _parseZoneMinutes(event['zoneMinutes']) ?? prev?.zoneMinutes ?? const [0, 0, 0, 0, 0],
              currentStressScore: event['currentStressScore'] as int? ?? prev?.currentStressScore ?? 0,
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
          if (event['isScanComplete'] == true) {
            return;
          }
          final name = event['name'] as String? ?? 'Unknown';
          final address = event['address'] as String? ?? '';
          final rssi = event['rssi'] as int? ?? -70;

          if (address.isNotEmpty) {
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
  static List<int>? _parseZoneMinutes(dynamic raw) {
    if (raw is! List) return null;
    final out = raw.map((e) => (e as num).round()).toList();
    if (out.length < 5) return null;
    return out.take(5).toList();
  }

  void dispose() {
    _scanSub?.cancel();
    _eventSub?.cancel();
    _scanController.close();
    _telemetryController.close();
  }
}
