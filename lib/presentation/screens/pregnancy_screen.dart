import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/pregnancy_log_repository.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/intelligence/pregnancy_engine.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/glass_card.dart';

class PregnancyScreen extends StatefulWidget {
  final UteBleBridge bleBridge;
  const PregnancyScreen({super.key, required this.bleBridge});

  @override
  State<PregnancyScreen> createState() => _PregnancyScreenState();
}

class _PregnancyScreenState extends State<PregnancyScreen> {
  UserProfile _profile = const UserProfile(gender: Gender.female, isPregnant: true);
  PregnancyDayLog _log = const PregnancyDayLog();
  final _note = TextEditingController();

  bool get _ru => AppLocaleNotifier.current != AppLanguage.kyrgyz;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await UserProfileRepository.loadProfile();
    final log = await PregnancyLogRepository.load(DateTime.now());
    if (!mounted) return;
    setState(() {
      _profile = p;
      _log = log;
      _note.text = log.note;
    });
  }

  Future<void> _saveLog() async {
    final next = PregnancyDayLog(energy: _log.energy, nausea: _log.nausea, kicks: _log.kicks, note: _note.text.trim());
    await PregnancyLogRepository.save(DateTime.now(), next);
    setState(() => _log = next);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_ru ? 'День записан' : 'Күн жазылды')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final status = PregnancyEngine.analyze(due: _profile.pregnancyDueDate, lmp: _profile.pregnancyLmpDate);
    final rhr = widget.bleBridge.currentTelemetry.restingHeartRate;
    final hrv = widget.bleBridge.currentTelemetry.hrv;

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.bg,
        title: Text(_ru ? 'Беременность' : 'Кош бойлуулук', style: AppTypography.screenTitle(palette.fg)),
        actions: [
          IconButton(icon: Icon(Icons.tune, color: palette.secondary), onPressed: _openSetup),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_ru ? 'Неделя ${status.week}' : '${status.week}-жума', style: TextStyle(color: AppColors.rose, fontSize: 28, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                _ru
                    ? '${status.trimester}-й триместр · до даты ${status.daysUntilDue} дн.'
                    : '${status.trimester}-триместр · ${status.daysUntilDue} күн калды',
                style: AppTypography.caption(palette.secondary),
              ),
              const SizedBox(height: 12),
              Text(
                _ru ? 'Нагрузка ${status.strainMin.toStringAsFixed(0)}–${status.strainMax.toStringAsFixed(0)}' : 'Жүктөм ${status.strainMin.toStringAsFixed(0)}–${status.strainMax.toStringAsFixed(0)}',
                style: AppTypography.bodySemibold(palette.fg),
              ),
              const SizedBox(height: 6),
              Text(_ru ? status.trainingRu : status.trainingKy, style: AppTypography.caption(palette.secondary).copyWith(height: 1.35)),
              const SizedBox(height: 8),
              Text(_ru ? status.bodyRu : status.bodyKy, style: AppTypography.caption(palette.fg).copyWith(height: 1.35)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _metric(palette, 'RHR', '${rhr > 0 ? rhr : '—'}')),
            const SizedBox(width: 8),
            Expanded(child: _metric(palette, 'HRV', hrv > 0 ? hrv.toStringAsFixed(0) : '—')),
          ]),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_ru ? 'Сегодня' : 'Бүгүн', style: AppTypography.bodySemibold(palette.fg)),
              const SizedBox(height: 8),
              Text('${_ru ? 'Энергия' : 'Энергия'} ${_log.energy}/5', style: AppTypography.caption(palette.secondary)),
              Slider(value: _log.energy.toDouble(), min: 1, max: 5, divisions: 4, activeColor: AppColors.sage, onChanged: (v) => setState(() => _log = PregnancyDayLog(energy: v.round(), nausea: _log.nausea, kicks: _log.kicks, note: _note.text))),
              Text('${_ru ? 'Тошнота' : 'Жүрөк айлануу'} ${_log.nausea}/3', style: AppTypography.caption(palette.secondary)),
              Slider(value: _log.nausea.toDouble(), min: 0, max: 3, divisions: 3, activeColor: AppColors.rose, onChanged: (v) => setState(() => _log = PregnancyDayLog(energy: _log.energy, nausea: v.round(), kicks: _log.kicks, note: _note.text))),
              if (status.week >= 28) ...[
                Text('${_ru ? 'Шевеления' : 'Кыймыл'} ${_log.kicks}', style: AppTypography.caption(palette.secondary)),
                Row(children: [
                  IconButton(onPressed: () => setState(() => _log = PregnancyDayLog(energy: _log.energy, nausea: _log.nausea, kicks: (_log.kicks - 1).clamp(0, 99), note: _note.text)), icon: Icon(Icons.remove_circle_outline)),
                  Text('${_log.kicks}', style: AppTypography.metricValue(palette.fg)),
                  IconButton(onPressed: () => setState(() => _log = PregnancyDayLog(energy: _log.energy, nausea: _log.nausea, kicks: _log.kicks + 1, note: _note.text)), icon: Icon(Icons.add_circle_outline)),
                ]),
              ],
              TextField(controller: _note, maxLines: 2, decoration: InputDecoration(hintText: _ru ? 'Заметка врачу или себе' : 'Белги')),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveLog,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white, elevation: 0),
                  child: Text(_ru ? 'Сохранить день' : 'Күндү сактоо'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Text(
            _ru
                ? 'Это не медицинское приложение и не Flo. Решения по нагрузке — с врачом.'
                : 'Бул медициналык колдонмо эмес. Жүктөм боюнча чечимди дарыгер менен алыңыз.',
            style: AppTypography.caption(palette.muted).copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _metric(KalkanColors palette, String l, String v) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: palette.hairline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: AppTypography.caption(palette.secondary)),
        const SizedBox(height: 4),
        Text(v, style: AppTypography.metricValue(palette.fg)),
      ]),
    );
  }

  void _openSetup() {
    DateTime due = _profile.pregnancyDueDate ?? DateTime.now().add(const Duration(days: 196));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(_ru ? 'Срок' : 'Мөөнөт', style: TextStyle(color: AppColors.fg)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: due, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 300)));
              if (picked != null) due = picked;
            },
            child: Text(_ru ? 'Предполагаемые роды' : 'Божомолдонгон төрөт'),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: DateTime.now().subtract(const Duration(days: 84)), firstDate: DateTime.now().subtract(const Duration(days: 300)), lastDate: DateTime.now());
              if (picked != null) {
                due = PregnancyEngine.dueFromLmp(picked);
                final updated = _profile.copyWith(isPregnant: true, pregnancyLmpDate: picked, pregnancyDueDate: due);
                await UserProfileRepository.saveProfile(updated);
                if (mounted) setState(() => _profile = updated);
              }
            },
            child: Text(_ru ? 'От первых месячных (LMP)' : 'Акыркы этек кирден'),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final updated = _profile.copyWith(isPregnant: false);
              await UserProfileRepository.saveProfile(updated);
              if (mounted) setState(() => _profile = updated);
            },
            child: Text(_ru ? 'Выключить режим' : 'Режимди өчүрүү'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final updated = _profile.copyWith(isPregnant: true, pregnancyDueDate: due, pregnancyLmpDate: PregnancyEngine.lmpFromDue(due));
              await UserProfileRepository.saveProfile(updated);
              if (mounted) setState(() => _profile = updated);
            },
            child: Text(_ru ? 'Сохранить' : 'Сактоо'),
          ),
        ],
      ),
    );
  }
}
