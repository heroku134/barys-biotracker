import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/telemetry.dart';
import 'ble_simulator.dart';
import '../storage/demo_mode_store.dart';

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

  final BleSimulator _simulator = BleSimulator();
  final StreamController<BleTelemetry> _telemetryController = StreamController.broadcast();
  final StreamController<List<DiscoveredBleDevice>> _scanController =
      StreamController<List<DiscoveredBleDevice>>.broadcast();

  final Map<String, DiscoveredBleDevice> _discoveredMap = {};
  bool _useSimulator = true;
  StreamSubscription? _eventSub;
  StreamSubscription? _scanSub;
  BleTelemetry? _realTelemetry;

  Stream<BleTelemetry> get telemetryStream => _telemetryController.stream;
  Stream<List<DiscoveredBleDevice>> get scanResultsStream => _scanController.stream;
  List<DiscoveredBleDevice> get discoveredDevices =>
      _discoveredMap.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));

  BleTelemetry get currentTelemetry {
    if (isSimulatorActive) return _simulator.current;
    return _realTelemetry ?? BleTelemetry.empty();
  }

  bool get isSimulatorActive => _useSimulator && DemoModeStore.enabled.value;

  Future<void> init() async {
    await DemoModeStore.init();
    _useSimulator = DemoModeStore.enabled.value;
    _simulator.start();
    _simulator.telemetryStream.listen((data) {
      if (DemoModeStore.enabled.value) {
        _telemetryController.add(data);
      }
    });
    DemoModeStore.enabled.addListener(() {
      _useSimulator = DemoModeStore.enabled.value;
      _telemetryController.add(currentTelemetry);
    });

    try {
      _eventSub = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            _useSimulator = false;
            final isConnected = event['isConnected'] as bool? ?? true;
            final prev = _realTelemetry;

            final telemetry = BleTelemetry(
              heartRate: event['heartRate'] as int? ?? prev?.heartRate ?? 0,
              steps: event['steps'] as int? ?? prev?.steps ?? 0,
              calories: event['calories'] as int? ?? prev?.calories ?? 0,
              batteryLevel: event['batteryLevel'] as int? ?? prev?.batteryLevel ?? 0,
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
          if (DemoModeStore.enabled.value) _useSimulator = true;
        },
      );
    } catch (_) {
      if (DemoModeStore.enabled.value) _useSimulator = true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMac = prefs.getString('kalkan_last_device_mac');
      if (lastMac != null && lastMac.isNotEmpty) {
        connect(lastMac);
      }
    } catch (_) {}
  }

  // --- Проверка Bluetooth и разрешений ---

  Future<bool> isBluetoothEnabled() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('isBluetoothEnabled');
      return res ?? false;
    } catch (_) {
      return true; // в симуляторе
    }
  }

  Future<bool> checkPermissions() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('checkPermissions');
      return res ?? false;
    } catch (_) {
      return true;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('requestPermissions');
      return res ?? false;
    } catch (_) {
      return true;
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
    } catch (_) {}
  }

  Future<void> stopScan() async {
    try {
      await _methodChannel.invokeMethod('stopScan');
    } catch (_) {}
    _scanSub?.cancel();
  }

  // --- Управление подключением ---

  Future<void> connect(String macAddress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kalkan_last_device_mac', macAddress);
      await _methodChannel.invokeMethod('connect', {'address': macAddress});
      _useSimulator = false;
    } catch (_) {}
  }

  Future<void> disconnect({bool forget = false}) async {
    try {
      if (forget) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('kalkan_last_device_mac');
      }
      await _methodChannel.invokeMethod('disconnect');
    } catch (_) {}
    if (_realTelemetry != null) {
      _realTelemetry = _realTelemetry!.copyWith(isConnected: false);
      _telemetryController.add(_realTelemetry!);
    }
  }

  Future<String?> getLastPairedAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('kalkan_last_device_mac');
    } catch (_) {
      return null;
    }
  }

  // --- Команды часам ---

  Future<void> findWatch() async {
    try {
      await _methodChannel.invokeMethod('findDevice');
    } catch (_) {}
  }

  Future<void> syncTime() async {
    try {
      await _methodChannel.invokeMethod('syncTime');
    } catch (_) {}
  }

  Future<void> triggerHeartRateMeasurement() async {
    try {
      await _methodChannel.invokeMethod('measureHeartRate');
    } catch (_) {}
  }

  // --- Демо-режим и симуляция ---

  bool get isTiredDemo => _simulator.isSimulatedTired;
  bool get isCrisisDemo => _simulator.isCrisisDemo;

  void setDemoTired(bool tired) {
    DemoModeStore.setEnabled(true);
    _useSimulator = true;
    _simulator.toggleTiredDemo(tired);
  }

  void setDemoCrisis(bool crisis) {
    DemoModeStore.setEnabled(true);
    _useSimulator = true;
    _simulator.toggleCrisisDemo(crisis);
  }

  void setDemoStrain(double strain) {
    DemoModeStore.setEnabled(true);
    _useSimulator = true;
    _simulator.setSimulatedStrain(strain);
  }

  void setSimulatedMetrics({double? strain, int? steps, int? sleepMinutes}) {
    DemoModeStore.setEnabled(true);
    _useSimulator = true;
    _simulator.setSimulatedMetrics(strain: strain, steps: steps, sleepMinutes: sleepMinutes);
  }

  void activateSimulatorMode() {
    DemoModeStore.setEnabled(true);
    _useSimulator = true;
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
    _simulator.dispose();
    _telemetryController.close();
  }
}
