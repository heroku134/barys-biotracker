import 'package:shared_preferences/shared_preferences.dart';

class PregnancyDayLog {
  final int energy;
  final int nausea;
  final int kicks;
  final String note;

  const PregnancyDayLog({this.energy = 3, this.nausea = 0, this.kicks = 0, this.note = ''});
}

class PregnancyLogRepository {
  static String _key(DateTime d) {
    final s = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return 'kalkan_preg_$s';
  }

  static Future<PregnancyDayLog> load(DateTime d) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(d));
    if (raw == null) return const PregnancyDayLog();
    final parts = raw.split('|');
    return PregnancyDayLog(
      energy: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 3,
      nausea: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
      kicks: int.tryParse(parts.length > 2 ? parts[2] : '') ?? 0,
      note: parts.length > 3 ? parts.sublist(3).join('|') : '',
    );
  }

  static Future<void> save(DateTime d, PregnancyDayLog log) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(d), '${log.energy}|${log.nausea}|${log.kicks}|${log.note}');
  }
}
