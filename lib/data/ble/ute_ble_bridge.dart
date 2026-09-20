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
  BleTelemetry? _realTelemetry;

  Stream<BleTelemetry> get telemetryStream => _telemetryController.stream;
  BleTelemetry get currentTelemetry =>
      (!_useSimulator && _realTelemetry != null) ? _realTelemetry! : _simulator.current;
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
            final isConnected = event['isConnected'] as bool? ?? true;
            final prev = _realTelemetry ?? _simulator.current;

            final telemetry = BleTelemetry(
              heartRate: event['heartRate'] as int? ?? prev.heartRate,
              steps: event['steps'] as int? ?? prev.steps,
              calories: event['calories'] as int? ?? prev.calories,
              batteryLevel: event['batteryLevel'] as int? ?? prev.batteryLevel,
              isConnected: isConnected,
              deviceName: event['deviceName'] as String? ?? (isConnected ? 'KALKAN СААТ-1' : prev.deviceName),
              timestamp: DateTime.now(),
              hrv: (event['hrv'] as num?)?.toDouble() ?? prev.hrv,
              restingHeartRate: event['restingHeartRate'] as int? ?? prev.restingHeartRate,
              respiratoryRate: (event['respiratoryRate'] as num?)?.toDouble() ?? prev.respiratoryRate,
              skinTempDeviation: (event['skinTempDeviation'] as num?)?.toDouble() ?? prev.skinTempDeviation,
              isOffWrist: event['isOffWrist'] as bool? ?? prev.isOffWrist,
              sleepMinutes: event['sleepMinutes'] as int? ?? prev.sleepMinutes,
              deepSleepMinutes: event['deepSleepMinutes'] as int? ?? prev.deepSleepMinutes,
              remSleepMinutes: event['remSleepMinutes'] as int? ?? prev.remSleepMinutes,
              timeInBedMinutes: event['timeInBedMinutes'] as int? ?? prev.timeInBedMinutes,
              sleepEfficiency: (event['sleepEfficiency'] as num?)?.toDouble() ?? prev.sleepEfficiency,
              sleepConsistency: (event['sleepConsistency'] as num?)?.toDouble() ?? prev.sleepConsistency,
              restorativeSleepRatio: (event['restorativeSleepRatio'] as num?)?.toDouble() ?? prev.restorativeSleepRatio,
              currentDayStrain: (event['currentDayStrain'] as num?)?.toDouble() ?? prev.currentDayStrain,
              yesterdayStrain: (event['yesterdayStrain'] as num?)?.toDouble() ?? prev.yesterdayStrain,
              zoneMinutes: event['zoneMinutes'] is List<int>
                  ? (event['zoneMinutes'] as List<int>)
                  : prev.zoneMinutes,
              currentStressScore: event['currentStressScore'] as int? ?? prev.currentStressScore,
            );

            _realTelemetry = telemetry;
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

  void setSimulatedMetrics({double? strain, int? steps, int? sleepMinutes}) {
    _useSimulator = true;
    _simulator.setSimulatedMetrics(strain: strain, steps: steps, sleepMinutes: sleepMinutes);
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
    if (_realTelemetry != null) {
      _realTelemetry = _realTelemetry!.copyWith(isConnected: false);
      _telemetryController.add(_realTelemetry!);
    }
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
