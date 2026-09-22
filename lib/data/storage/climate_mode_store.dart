import 'package:shared_preferences/shared_preferences.dart';

enum ClimateMode { normal, altitude, heat }

class ClimateModeStore {
  static const _key = 'kalkan_climate_mode_v1';

  static ClimateMode _from(String? raw) {
    switch (raw) {
      case 'altitude':
        return ClimateMode.altitude;
      case 'heat':
        return ClimateMode.heat;
      default:
        return ClimateMode.normal;
    }
  }

  static Future<ClimateMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    return _from(prefs.getString(_key));
  }

  static Future<void> save(ClimateMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  static double strainFactor(ClimateMode mode) {
    switch (mode) {
      case ClimateMode.altitude:
        return 0.82;
      case ClimateMode.heat:
        return 0.88;
      case ClimateMode.normal:
        return 1.0;
    }
  }
}
