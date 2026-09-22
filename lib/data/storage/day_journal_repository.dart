import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DayJournalEntry {
  final String dateKey;
  final double? sleepHours;
  final String sleepNote;
  final String workoutNote;
  final String note;
  final DateTime updatedAt;

  const DayJournalEntry({
    required this.dateKey,
    this.sleepHours,
    this.sleepNote = '',
    this.workoutNote = '',
    this.note = '',
    required this.updatedAt,
  });

  bool get isEmpty =>
      sleepHours == null && sleepNote.isEmpty && workoutNote.isEmpty && note.isEmpty;

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'sleepHours': sleepHours,
        'sleepNote': sleepNote,
        'workoutNote': workoutNote,
        'note': note,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DayJournalEntry.fromJson(Map<String, dynamic> json) {
    return DayJournalEntry(
      dateKey: json['dateKey'] as String? ?? '',
      sleepHours: (json['sleepHours'] as num?)?.toDouble(),
      sleepNote: json['sleepNote'] as String? ?? '',
      workoutNote: json['workoutNote'] as String? ?? '',
      note: json['note'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  static String keyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class DayJournalRepository {
  static const _key = 'kalkan_day_journal_v1';

  static Future<List<DayJournalEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final items = <DayJournalEntry>[];
    for (final s in raw) {
      try {
        items.add(DayJournalEntry.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    items.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return items;
  }

  static Future<DayJournalEntry?> loadDay(DateTime day) async {
    final key = DayJournalEntry.keyFor(day);
    final all = await loadAll();
    for (final e in all) {
      if (e.dateKey == key) return e;
    }
    return null;
  }

  static Future<void> save(DayJournalEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();
    all.removeWhere((e) => e.dateKey == entry.dateKey);
    all.insert(0, entry);
    await prefs.setStringList(_key, all.map((e) => jsonEncode(e.toJson())).toList());
  }
}
