import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PregnancyDayLog {
  final int energy;
  final int nausea;
  final int kicks;
  final int waterGlasses;
  final double? weightKg;
  final bool vitamins;
  final bool intercourse;
  final String note;

  const PregnancyDayLog({
    this.energy = 3,
    this.nausea = 0,
    this.kicks = 0,
    this.waterGlasses = 0,
    this.weightKg,
    this.vitamins = false,
    this.intercourse = false,
    this.note = '',
  });

  PregnancyDayLog copyWith({
    int? energy,
    int? nausea,
    int? kicks,
    int? waterGlasses,
    double? weightKg,
    bool? vitamins,
    bool? intercourse,
    String? note,
  }) {
    return PregnancyDayLog(
      energy: energy ?? this.energy,
      nausea: nausea ?? this.nausea,
      kicks: kicks ?? this.kicks,
      waterGlasses: waterGlasses ?? this.waterGlasses,
      weightKg: weightKg ?? this.weightKg,
      vitamins: vitamins ?? this.vitamins,
      intercourse: intercourse ?? this.intercourse,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'energy': energy,
        'nausea': nausea,
        'kicks': kicks,
        'water': waterGlasses,
        'weight': weightKg,
        'vitamins': vitamins,
        'sex': intercourse,
        'note': note,
      };

  factory PregnancyDayLog.fromJson(Map<String, dynamic> j) => PregnancyDayLog(
        energy: (j['energy'] as num?)?.toInt() ?? 3,
        nausea: (j['nausea'] as num?)?.toInt() ?? 0,
        kicks: (j['kicks'] as num?)?.toInt() ?? 0,
        waterGlasses: (j['water'] as num?)?.toInt() ?? 0,
        weightKg: (j['weight'] as num?)?.toDouble(),
        vitamins: j['vitamins'] as bool? ?? false,
        intercourse: j['sex'] as bool? ?? false,
        note: j['note'] as String? ?? '',
      );
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
    if (raw.startsWith('{')) {
      try {
        return PregnancyDayLog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
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
    await prefs.setString(_key(d), jsonEncode(log.toJson()));
  }
}
