import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/telemetry.dart';
import 'demo_mode_store.dart';
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
    final today = DaySnapshot.keyFor(DateTime.now());
    await upsert(DaySnapshot(
      dateKey: today,
      recovery: recovery,
      strain: t.currentDayStrain > 0 ? t.currentDayStrain : 0,
      sleep: sleep,
      hrv: t.hrv,
      rhr: t.restingHeartRate,
      preview: !t.isConnected,
    ));
  }

  static Future<void> purgePreviewIfDemoOff() async {
    if (DemoModeStore.enabled.value) return;
    final all = await loadAll();
    final kept = all.where((s) => !s.preview).toList();
    if (kept.length != all.length) await _saveAll(kept);
  }

  /// Fills empty history so Analysis is testable without a watch.
  static Future<void> seedPreviewIfEmpty(BleTelemetry t) async {
    await purgePreviewIfDemoOff();
    final all = await loadAll();
    if (all.isNotEmpty || !DemoModeStore.enabled.value) return;
    final baseHrv = t.hrv > 0 ? t.hrv : 64.0;
    final baseRhr = t.restingHeartRate > 0 ? t.restingHeartRate : 52;
    for (int i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      await upsert(DaySnapshot(
        dateKey: DaySnapshot.keyFor(d),
        recovery: (72 + (i * 3) % 18).clamp(45, 96),
        strain: 8.5 + (i % 5) * 1.4,
        sleep: (78 + (i * 5) % 16).clamp(55, 98),
        hrv: baseHrv + ((i % 3) - 1) * 4,
        rhr: baseRhr + (i % 3) - 1,
        preview: true,
      ));
    }
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
