import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';
import '../../data/storage/day_journal_repository.dart';

class DayJournalScreen extends StatefulWidget {
  const DayJournalScreen({super.key});

  @override
  State<DayJournalScreen> createState() => _DayJournalScreenState();
}

class _DayJournalScreenState extends State<DayJournalScreen> {
  final _sleepNote = TextEditingController();
  final _workoutNote = TextEditingController();
  final _note = TextEditingController();
  double _sleepHours = 7.5;
  bool _hasSleep = false;
  List<DayJournalEntry> _history = [];

  bool get _ru => AppLocaleNotifier.current != AppLanguage.kyrgyz;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final today = await DayJournalRepository.loadDay(DateTime.now());
    final all = await DayJournalRepository.loadAll();
    if (!mounted) return;
    setState(() {
      if (today != null) {
        _hasSleep = today.sleepHours != null;
        _sleepHours = today.sleepHours ?? 7.5;
        _sleepNote.text = today.sleepNote;
        _workoutNote.text = today.workoutNote;
        _note.text = today.note;
      }
      _history = all;
    });
  }

  Future<void> _save() async {
    await DayJournalRepository.save(DayJournalEntry(
      dateKey: DayJournalEntry.keyFor(DateTime.now()),
      sleepHours: _hasSleep ? _sleepHours : null,
      sleepNote: _sleepNote.text.trim(),
      workoutNote: _workoutNote.text.trim(),
      note: _note.text.trim(),
      updatedAt: DateTime.now(),
    ));
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_ru ? 'День записан' : 'Күн жазылды')),
      );
    }
  }

  @override
  void dispose() {
    _sleepNote.dispose();
    _workoutNote.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.bg,
        title: Text(_ru ? 'Дневник дня' : 'Күндөлүк', style: AppTypography.screenTitle(palette.fg)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(_ru ? 'Сегодня' : 'Бүгүн', style: AppTypography.bodySemibold(palette.fg)),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_ru ? 'Отметить сон' : 'Уйкуну белгилөө', style: TextStyle(color: palette.fg)),
            value: _hasSleep,
            activeColor: AppColors.sleepBlue,
            onChanged: (v) => setState(() => _hasSleep = v),
          ),
          if (_hasSleep) ...[
            Text('${_sleepHours.toStringAsFixed(1)} ${_ru ? 'ч' : 'с'}', style: AppTypography.metricValue(palette.fg)),
            Slider(
              value: _sleepHours,
              min: 4,
              max: 12,
              divisions: 16,
              activeColor: AppColors.sleepBlue,
              onChanged: (v) => setState(() => _sleepHours = v),
            ),
            TextField(
              controller: _sleepNote,
              decoration: InputDecoration(hintText: _ru ? 'Как спалось' : 'Кантип уктадыңыз'),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _workoutNote,
            decoration: InputDecoration(hintText: _ru ? 'Тренировка' : 'Машыгуу'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: InputDecoration(hintText: _ru ? 'Заметка дня' : 'Күндүн белгиси'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white, elevation: 0),
            child: Text(_ru ? 'Сохранить' : 'Сактоо'),
          ),
          const SizedBox(height: 28),
          Text(_ru ? 'История' : 'Тарых', style: AppTypography.bodySemibold(palette.fg)),
          const SizedBox(height: 8),
          if (_history.isEmpty)
            Text(_ru ? 'Пока пусто' : 'Азырынча бош', style: AppTypography.caption(palette.secondary)),
          ..._history.map((e) {
            final parts = <String>[];
            if (e.sleepHours != null) parts.add('${e.sleepHours!.toStringAsFixed(1)} ч');
            if (e.workoutNote.isNotEmpty) parts.add(e.workoutNote);
            if (e.note.isNotEmpty) parts.add(e.note);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.dateKey, style: AppTypography.caption(palette.secondary)),
                  const SizedBox(height: 4),
                  Text(parts.isEmpty ? '—' : parts.join(' · '), style: TextStyle(color: palette.fg, height: 1.35)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
