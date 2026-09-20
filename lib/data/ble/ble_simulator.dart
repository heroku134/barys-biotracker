import 'dart:async';
import 'dart:math' as math;
import '../../domain/models/telemetry.dart';

/// Симулятор реальной телеметрии часов (пульс, шаги, батарея, сон, ВСР, ночные биомаркеры)
class BleSimulator {
  final _controller = StreamController<BleTelemetry>.broadcast();
  Timer? _timer;
  double _phase = 0.0;

  // Текущие значения
  int _steps = 7420;
  int _calories = 460;
  int _heartRate = 72;
  double _hrv = 66.0;
  int _restingHeartRate = 51;
  double _respiratoryRate = 14.2;
  double _skinTempDeviation = 0.1;
  int _sleepMinutes = 465;
  int _deepSleepMinutes = 115;
  int _remSleepMinutes = 95;
  int _timeInBedMinutes = 505;
  double _sleepEfficiency = 0.92;
  double _sleepConsistency = 0.88;
  double _restorativeSleepRatio = 0.78;
  double _currentDayStrain = 11.4;
  double _yesterdayStrain = 13.6;
  List<int> _zoneMinutes = [70, 45, 20, 8, 2];
  int _currentStressScore = 32;
  bool _isSimulatedTired = false;
  bool _isOffWrist = false;

  Stream<BleTelemetry> get telemetryStream => _controller.stream;

  BleTelemetry get current => _generateTelemetry();

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _phase += 0.1;
      _steps += 2 + math.Random().nextInt(4);
      _calories = (_steps * 0.045).round();

      // Физиологическое естественное колебание пульса
      final drift = (math.sin(_phase) * 4).round();
      if (_isCrisisDemo) {
        _heartRate = 118 + (math.sin(_phase) * 2).round();
        _hrv = 22.0 + (math.cos(_phase) * 2);
        _restingHeartRate = 78;
        _respiratoryRate = 19.5;
        _skinTempDeviation = 0.95;
        _sleepMinutes = 240;
        _deepSleepMinutes = 20;
        _remSleepMinutes = 30;
        _timeInBedMinutes = 360;
        _sleepEfficiency = 0.62;
        _sleepConsistency = 0.50;
        _restorativeSleepRatio = 0.25;
        _currentDayStrain = 18.5;
        _yesterdayStrain = 19.0;
        _zoneMinutes = [15, 20, 45, 55, 35];
        _currentStressScore = 89;
      } else if (_isSimulatedTired) {
        _heartRate = 88 + drift; // Тахикардия при усталости
        _hrv = 34.0 + (math.cos(_phase) * 3);
        _restingHeartRate = 62;
        _respiratoryRate = 16.5;
        _skinTempDeviation = 0.55; // Повышенная температура кожи
        _sleepMinutes = 320;
        _deepSleepMinutes = 40;
        _remSleepMinutes = 50;
        _timeInBedMinutes = 410;
        _sleepEfficiency = 0.78;
        _sleepConsistency = 0.65;
        _restorativeSleepRatio = 0.42;
        _currentDayStrain = 17.2;
        _yesterdayStrain = 18.0;
        _zoneMinutes = [40, 25, 45, 30, 15];
        _currentStressScore = 74;
      } else {
        _heartRate = 70 + drift;
        _hrv = 66.0 + (math.cos(_phase) * 3);
        _restingHeartRate = 51;
        _respiratoryRate = 14.2;
        _skinTempDeviation = 0.1;
        _sleepMinutes = 465;
        _deepSleepMinutes = 115;
        _remSleepMinutes = 95;
        _timeInBedMinutes = 505;
        _sleepEfficiency = 0.92;
        _sleepConsistency = 0.88;
        _restorativeSleepRatio = 0.78;
        _currentDayStrain = 11.4;
        _yesterdayStrain = 13.6;
        _zoneMinutes = [70, 45, 20, 8, 2];
        _currentStressScore = 32;
      }

      _controller.add(_generateTelemetry());
    });
  }

  bool _isCrisisDemo = false;
  bool get isCrisisDemo => _isCrisisDemo;
  bool get isSimulatedTired => _isSimulatedTired;

  void toggleTiredDemo(bool tired) {
    _isSimulatedTired = tired;
    _controller.add(_generateTelemetry());
  }

  void toggleCrisisDemo(bool crisis) {
    _isCrisisDemo = crisis;
    if (crisis) {
      _heartRate = 118;
      _hrv = 22.0;
      _restingHeartRate = 78;
      _respiratoryRate = 19.5;
      _skinTempDeviation = 0.95;
      _currentDayStrain = 18.5;
      _yesterdayStrain = 19.0;
      _currentStressScore = 89;
    }
    _controller.add(_generateTelemetry());
  }

  void toggleOffWristDemo(bool offWrist) {
    _isOffWrist = offWrist;
    _controller.add(_generateTelemetry());
  }

  void setSimulatedStrain(double strain) {
    _currentDayStrain = strain;
    _controller.add(_generateTelemetry());
  }

  BleTelemetry _generateTelemetry() {
    return BleTelemetry(
      heartRate: _heartRate,
      steps: _steps,
      calories: _calories,
      batteryLevel: 84,
      hrv: _hrv,
      restingHeartRate: _restingHeartRate,
      respiratoryRate: _respiratoryRate,
      skinTempDeviation: _skinTempDeviation,
      isOffWrist: _isOffWrist,
      sleepMinutes: _sleepMinutes,
      deepSleepMinutes: _deepSleepMinutes,
      remSleepMinutes: _remSleepMinutes,
      timeInBedMinutes: _timeInBedMinutes,
      sleepEfficiency: _sleepEfficiency,
      sleepConsistency: _sleepConsistency,
      restorativeSleepRatio: _restorativeSleepRatio,
      currentDayStrain: _currentDayStrain,
      yesterdayStrain: _yesterdayStrain,
      zoneMinutes: _zoneMinutes,
      currentStressScore: _currentStressScore,
      isConnected: true,
      deviceName: 'KALKAN СААТ-1',
      timestamp: DateTime.now(),
    );
  }

  void stop() {
    _timer?.cancel();
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
