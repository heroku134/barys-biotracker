import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/models/telemetry.dart';
import 'ble_simulator.dart';

/// Мост к нативному BLE SDK (UTE Nadal Android AAR + iOS CoreBluetooth Framework)
class UteBleBridge {
  static const MethodChannel _methodChannel = MethodChannel('com.nadal.ble/methods');
  static const EventChannel _eventChannel = EventChannel('com.nadal.ble/telemetry');

  final BleSimulator _simulator = BleSimulator();
  final StreamController<BleTelemetry> _telemetryController = StreamController.broadcast();

  bool _useSimulator = true;
  StreamSubscription? _eventSub;

  Stream<BleTelemetry> get telemetryStream => _telemetryController.stream;
  BleTelemetry get currentTelemetry => _simulator.current;
  bool get isSimulatorActive => _useSimulator;

  Future<void> init() async {
    _simulator.start();
    _simulator.telemetryStream.listen((data) {
      if (_useSimulator) {
        _telemetryController.add(data);
      }
    });

    try {
      _eventSub = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            _useSimulator = false;
            final telemetry = BleTelemetry(
              heartRate: event['heartRate'] as int? ?? 72,
              steps: event['steps'] as int? ?? 0,
              calories: event['calories'] as int? ?? 0,
              batteryLevel: event['batteryLevel'] as int? ?? 80,
              hrv: (event['hrv'] as num?)?.toDouble() ?? 60.0,
              sleepMinutes: event['sleepMinutes'] as int? ?? 420,
              deepSleepMinutes: event['deepSleepMinutes'] as int? ?? 90,
              isConnected: event['isConnected'] as bool? ?? true,
              deviceName: event['deviceName'] as String? ?? 'UTE Smart Band',
              timestamp: DateTime.now(),
            );
            _telemetryController.add(telemetry);
          }
        },
        onError: (err) {
          // При отсутствии нативного подключения плавно работаем в симуляторе
          _useSimulator = true;
        },
      );
    } catch (_) {
      _useSimulator = true;
    }
  }

  bool get isTiredDemo => _simulator.isSimulatedTired;
  bool get isCrisisDemo => _simulator.isCrisisDemo;

  void setDemoTired(bool tired) {
    _useSimulator = true;
    _simulator.toggleTiredDemo(tired);
  }

  void setDemoCrisis(bool crisis) {
    _useSimulator = true;
    _simulator.toggleCrisisDemo(crisis);
  }

  void setDemoStrain(double strain) {
    _useSimulator = true;
    _simulator.setSimulatedStrain(strain);
  }

  Future<void> startScan() async {
    try {
      await _methodChannel.invokeMethod('startScan');
    } catch (_) {}
  }

  Future<void> connect(String macAddress) async {
    try {
      await _methodChannel.invokeMethod('connect', {'address': macAddress});
    } catch (_) {}
  }

  Future<void> disconnect() async {
    try {
      await _methodChannel.invokeMethod('disconnect');
    } catch (_) {}
  }

  Future<void> triggerHeartRateMeasurement() async {
    try {
      await _methodChannel.invokeMethod('measureHeartRate');
    } catch (_) {}
  }

  void dispose() {
    _eventSub?.cancel();
    _simulator.dispose();
    _telemetryController.close();
  }
}
