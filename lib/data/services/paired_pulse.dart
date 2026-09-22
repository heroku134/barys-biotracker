import 'package:shared_preferences/shared_preferences.dart';
import '../../core/circa_haptics.dart';
import '../ble/ute_ble_bridge.dart';

/// Phone + watch in one beat. Watch call is best-effort (silent if no SDK).
class PairedPulse {
  static DateTime? _last;

  static Future<void> play(
    UteBleBridge bridge, {
    PairedPulseKind kind = PairedPulseKind.confirm,
  }) async {
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < const Duration(milliseconds: 700)) {
      return;
    }
    _last = now;
    switch (kind) {
      case PairedPulseKind.confirm:
        await CircaHaptics.success();
        break;
      case PairedPulseKind.start:
        await CircaHaptics.workoutStart();
        break;
      case PairedPulseKind.finish:
        await CircaHaptics.workoutFinish();
        break;
      case PairedPulseKind.find:
        await CircaHaptics.heavyAlert();
        break;
    }
    try {
      await bridge.findWatch();
    } catch (_) {}
  }

  static Future<void> morningIfNeeded(UteBleBridge bridge) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'kalkan_morning_pulse_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    if (prefs.getBool(key) ?? false) return;
    final hour = DateTime.now().hour;
    if (hour < 5 || hour >= 11) return;
    await prefs.setBool(key, true);
    await play(bridge, kind: PairedPulseKind.confirm);
  }
}

enum PairedPulseKind { confirm, start, finish, find }
