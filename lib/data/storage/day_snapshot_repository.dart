import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/telemetry.dart';
import '../services/cloud_sync_service.dart';

class DaySnapshot {
  final String dateKey;
  final int recovery;
  final double strain;
  final int sleep;
  final double hrv;
  final int rhr;
  final bool preview;

  const DaySnapshot({
    required this.dateKey,
    required this.recovery,
    required this.strain,
    required this.sleep,
    required this.hrv,
    required this.rhr,
    this.preview = false,
  });

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'recovery': recovery,
        'strain': strain,
        'sleep': sleep,
        'hrv': hrv,
        'rhr': rhr,
        'preview': preview,
      };

  factory DaySnapshot.fromJson(Map<String, dynamic> j) => DaySnapshot(
        dateKey: j['dateKey'] as String? ?? '',
        recovery: (j['recovery'] as num?)?.toInt() ?? 0,
        strain: (j['strain'] as num?)?.toDouble() ?? 0,
        sleep: (j['sleep'] as num?)?.toInt() ?? 0,
        hrv: (j['hrv'] as num?)?.toDouble() ?? 0,
        rhr: (j['rhr'] as num?)?.toInt() ?? 0,
        preview: j['preview'] as bool? ?? false,
      );

  static String keyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class DaySnapshotRepository {
  static const _key = 'kalkan_day_snapshots_v1';

  static Future<List<DaySnapshot>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final items = <DaySnapshot>[];
    for (final s in raw) {
      try {
        items.add(DaySnapshot.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    items.sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return items;
  }

  static Future<void> _saveAll(List<DaySnapshot> items) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = items.length > 60 ? items.sublist(items.length - 60) : items;
    await prefs.setStringList(_key, trimmed.map((e) => jsonEncode(e.toJson())).toList());
  }

  static Future<void> upsert(DaySnapshot snap) async {
    final all = await loadAll();
    all.removeWhere((e) => e.dateKey == snap.dateKey);
    all.add(snap);
    await _saveAll(all);
    CloudSyncService.pushDay(snap);
  }

  static Future<void> recordTelemetry(BleTelemetry t, {required int recovery, required int sleep}) async {
    // Не записываем пустые фиктивные замеры, если часы не подключены и нет никаких биометрических данных
    if (!t.isConnected && t.hrv <= 0 && t.restingHeartRate <= 0 && t.sleepMinutes <= 0 && t.currentDayStrain <= 0 && t.heartRate <= 0) {
      return;
    }
    final today = DaySnapshot.keyFor(DateTime.now());
    final all = await loadAll();
    DaySnapshot? existing;
    for (final s in all) {
      if (s.dateKey == today) {
        existing = s;
        break;
      }
    }

    final resolvedRhr = t.restingHeartRate > 0
        ? t.restingHeartRate
        : (t.heartRate > 0 ? t.heartRate : (existing?.rhr ?? 0));
    final resolvedHrv = t.hrv > 0 ? t.hrv : (existing?.hrv ?? 0.0);
    final resolvedStrain = t.currentDayStrain > 0 ? t.currentDayStrain : (existing?.strain ?? 0.0);
    final resolvedSleep = sleep > 0 ? sleep : (existing?.sleep ?? 0);
    final resolvedRecovery = recovery > 0 ? recovery : (existing?.recovery ?? 0);

    await upsert(DaySnapshot(
      dateKey: today,
      recovery: resolvedRecovery,
      strain: resolvedStrain,
      sleep: resolvedSleep,
      hrv: resolvedHrv,
      rhr: resolvedRhr,
      preview: false,
    ));
  }

  static Future<void> purgePreview() async {
    final all = await loadAll();
    final kept = all.where((s) => !s.preview).toList();
    if (kept.length != all.length) await _saveAll(kept);
  }

  /// Очищает устаревшие тестовые предпросмотры: работают только реальные замеры
  static Future<void> seedPreviewIfEmpty(BleTelemetry t) async {
    await purgePreview();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<List<DaySnapshot>> lastDays(int n) async {
    final all = await loadAll();
    if (all.length <= n) return all;
    return all.sublist(all.length - n);
  }

  static Future<DaySnapshot?> yesterday() async {
    final key = DaySnapshot.keyFor(DateTime.now().subtract(const Duration(days: 1)));
    final all = await loadAll();
    for (final s in all.reversed) {
      if (s.dateKey == key) return s;
    }
    return all.length >= 2 ? all[all.length - 2] : null;
  }

  static Future<String> exportJson() async {
    final all = await loadAll();
    return jsonEncode(all.map((e) => e.toJson()).toList());
  }

  static Future<void> importJson(String raw) async {
    final list = jsonDecode(raw) as List<dynamic>;
    final items = list.map((e) => DaySnapshot.fromJson(e as Map<String, dynamic>)).toList();
    await _saveAll(items);
  }
}
