import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';
import '../../data/storage/day_journal_repository.dart';
import '../widgets/glass_card.dart';

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
  String _mood = 'ok';
  bool _lateMeal = false;
  bool _alcohol = false;
  List<DayJournalEntry> _history = [];

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
        _mood = today.mood;
        _lateMeal = today.lateMeal;
        _alcohol = today.alcohol;
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
      mood: _mood,
      lateMeal: _lateMeal,
      alcohol: _alcohol,
      updatedAt: DateTime.now(),
    ));
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocaleNotifier.pick('День записан', 'Күн жазылды', 'Day saved'))),
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
        title: Text(AppLocaleNotifier.pick('Дневник дня', 'Күндөлүк', 'Day journal'), style: AppTypography.screenTitle(palette.fg)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(AppLocaleNotifier.pick('Что было сегодня', 'Бүгүн эмне болду', 'What happened today'), style: AppTypography.bodySemibold(palette.fg)),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppLocaleNotifier.pick('Сон', 'Уйку', 'Sleep'), style: AppTypography.bodySemibold(palette.fg)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppLocaleNotifier.pick('Записать часы сна', 'Уйку саатын жазуу', 'Log sleep hours'), style: TextStyle(color: palette.fg, fontSize: 14)),
                value: _hasSleep,
                onChanged: (v) => setState(() => _hasSleep = v),
              ),
              if (_hasSleep) ...[
                Text('${_sleepHours.toStringAsFixed(1)} h', style: AppTypography.metricValue(palette.fg)),
                Slider(value: _sleepHours, min: 4, max: 12, divisions: 16, activeColor: AppColors.sleepBlue, onChanged: (v) => setState(() => _sleepHours = v)),
                TextField(controller: _sleepNote, decoration: InputDecoration(hintText: AppLocaleNotifier.pick('Как спалось', 'Кантип уктадыңыз', 'How you slept'))),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppLocaleNotifier.pick('Настроение', 'Маанай', 'Mood'), style: AppTypography.bodySemibold(palette.fg)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                _moodChip(palette, 'low', AppLocaleNotifier.pick('Тяжело', 'Оор', 'Heavy')),
                _moodChip(palette, 'ok', AppLocaleNotifier.pick('Норма', 'Кадимки', 'Fine')),
                _moodChip(palette, 'high', AppLocaleNotifier.pick('Легко', 'Жеңил', 'Light')),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppLocaleNotifier.pick('Тренировка', 'Машыгуу', 'Workout'), style: AppTypography.bodySemibold(palette.fg)),
              TextField(controller: _workoutNote, decoration: InputDecoration(hintText: AppLocaleNotifier.pick('Что делали и как прошло', 'Эмне кылдыңыз', 'What you did'))),
            ]),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppLocaleNotifier.pick('Поздний ужин', 'Кеч кечки тамак', 'Late dinner'), style: TextStyle(color: palette.fg, fontSize: 14)),
                value: _lateMeal,
                onChanged: (v) => setState(() => _lateMeal = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppLocaleNotifier.pick('Алкоголь', 'Спирт', 'Alcohol'), style: TextStyle(color: palette.fg, fontSize: 14)),
                value: _alcohol,
                onChanged: (v) => setState(() => _alcohol = v),
              ),
              TextField(controller: _note, maxLines: 3, decoration: InputDecoration(hintText: AppLocaleNotifier.pick('Заметка себе', 'Белги', 'Note to self'))),
            ]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white, elevation: 0, minimumSize: const Size.fromHeight(48)),
            child: Text(AppLocaleNotifier.pick('Сохранить день', 'Күндү сактоо', 'Save day')),
          ),
          const SizedBox(height: 28),
          Text(AppLocaleNotifier.pick('История', 'Тарых', 'History'), style: AppTypography.bodySemibold(palette.fg)),
          const SizedBox(height: 8),
          if (_history.isEmpty)
            Text(AppLocaleNotifier.pick('Пока пусто', 'Азырынча бош', 'Empty so far'), style: AppTypography.caption(palette.secondary)),
          ..._history.map((e) {
            final bits = <String>[];
            if (e.sleepHours != null) bits.add('${e.sleepHours!.toStringAsFixed(1)} h');
            if (e.workoutNote.isNotEmpty) bits.add(e.workoutNote);
            if (e.lateMeal) bits.add(AppLocaleNotifier.pick('поздний ужин', 'кеч тамак', 'late dinner'));
            if (e.alcohol) bits.add(AppLocaleNotifier.pick('алкоголь', 'спирт', 'alcohol'));
            if (e.note.isNotEmpty) bits.add(e.note);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: palette.hairline)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.dateKey, style: AppTypography.caption(palette.secondary)),
                const SizedBox(height: 4),
                Text(bits.isEmpty ? '—' : bits.join(' · '), style: TextStyle(color: palette.fg, height: 1.35)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _moodChip(KalkanColors palette, String id, String label) {
    final on = _mood == id;
    return GestureDetector(
      onTap: () => setState(() => _mood = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppColors.sage.withValues(alpha: 0.16) : palette.raised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? AppColors.sage : palette.hairline),
        ),
        child: Text(label, style: TextStyle(color: palette.fg, fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}
