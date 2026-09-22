import 'package:shared_preferences/shared_preferences.dart';

class OnboardingRepository {
  static const _doneKey = 'kalkan_onboarding_done_v1';
  static const _calKey = 'kalkan_calibration_days_v1';

  static Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_doneKey) ?? false;
  }

  static Future<void> markDone({required bool startCalibration}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);
    if (startCalibration) {
      await prefs.setInt(_calKey, 0);
    } else {
      await prefs.setInt(_calKey, 14);
    }
  }

  static Future<int> calibrationDaysDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_calKey) ?? 14;
  }

  static Future<void> setCalibrationDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_calKey, days.clamp(0, 14));
  }
}
