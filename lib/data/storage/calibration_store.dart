import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/personal_baseline.dart';
import 'onboarding_repository.dart';

class CalibrationSnapshot {
  final int daysDone;
  final double meanHrv;
  final int meanRhr;
  final String? lastMorningKey;
  final int sampleCount;

  const CalibrationSnapshot({
    required this.daysDone,
    required this.meanHrv,
    required this.meanRhr,
    required this.lastMorningKey,
    required this.sampleCount,
  });

  bool get isCalibrating => daysDone < 14;
}

class CalibrationStore {
  static const _hrvKey = 'kalkan_cal_mean_hrv_v1';
  static const _rhrKey = 'kalkan_cal_mean_rhr_v1';
  static const _nKey = 'kalkan_cal_samples_v1';
  static const _lastKey = 'kalkan_cal_last_morning_v1';

  static String _todayKey([DateTime? d]) {
    final n = d ?? DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static Future<CalibrationSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    return CalibrationSnapshot(
      daysDone: prefs.getInt('kalkan_calibration_days_v1') ?? 0,
      meanHrv: prefs.getDouble(_hrvKey) ?? 64.0,
      meanRhr: prefs.getInt(_rhrKey) ?? 52,
      lastMorningKey: prefs.getString(_lastKey),
      sampleCount: prefs.getInt(_nKey) ?? 0,
    );
  }

  static Future<PersonalBaseline> loadBaseline({PersonalBaseline seed = const PersonalBaseline()}) async {
    final snap = await load();
    return seed.copyWith(
      calibrationDaysDone: snap.daysDone,
      meanHrv: snap.meanHrv,
      meanRhr: snap.meanRhr,
    );
  }

  /// One increment per calendar day when night HRV/RHR exists.
  static Future<bool> recordMorningSync({
    required double hrv,
    required int rhr,
    DateTime? now,
  }) async {
    final moment = now ?? DateTime.now();
    if (hrv <= 0) return false;
    final prefs = await SharedPreferences.getInstance();
    final key = _todayKey(moment);
    if (prefs.getString(_lastKey) == key) return false;

    final prevN = prefs.getInt(_nKey) ?? 0;
    final prevHrv = prefs.getDouble(_hrvKey) ?? hrv;
    final prevRhr = prefs.getInt(_rhrKey) ?? rhr;
    final n = prevN + 1;
    final nextHrv = ((prevHrv * prevN) + hrv) / n;
    final nextRhr = (((prevRhr * prevN) + rhr) / n).round();
    final days = ((prefs.getInt('kalkan_calibration_days_v1') ?? 0) + 1).clamp(0, 14);

    await prefs.setString(_lastKey, key);
    await prefs.setInt(_nKey, n);
    await prefs.setDouble(_hrvKey, nextHrv);
    await prefs.setInt(_rhrKey, nextRhr);
    await OnboardingRepository.setCalibrationDays(days);
    return true;
  }
}
