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

  String _t(String ru, String ky, String en) => AppLocaleNotifier.pick(ru, ky, en);

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
    final next = _log.copyWith(note: _note.text);
    await PregnancyLogRepository.save(DateTime.now(), next);
    setState(() => _log = next);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('День записан', 'Күн жазылды', 'Day saved'))));
    }
  }

  String _babySize(int week) {
    if (week < 8) return _t('Размер: как маковое зернышко', 'Көлөмү: көкнөр данындай', 'Size: like a poppy seed');
    if (week < 12) return _t('Размер: как лайм (~5 см)', 'Көлөмү: лаймдай (~5 см)', 'Size: like a lime (~5 cm)');
    if (week < 16) return _t('Размер: как авокадо (~11 см)', 'Көлөмү: авокадодой (~11 см)', 'Size: like an avocado (~11 cm)');
    if (week < 20) return _t('Размер: как банан (~16 см)', 'Көлөмү: банандай (~16 см)', 'Size: like a banana (~16 cm)');
    if (week < 24) return _t('Размер: как кукуруза (~30 см)', 'Көлөмү: жүгөрүдөй (~30 см)', 'Size: like corn (~30 cm)');
    if (week < 28) return _t('Размер: как баклажан (~37 см)', 'Көлөмү: баклажандай (~37 см)', 'Size: like an eggplant (~37 cm)');
    if (week < 32) return _t('Размер: как кокос (~42 см)', 'Көлөмү: кокостой (~42 см)', 'Size: like a coconut (~42 cm)');
    if (week < 36) return _t('Размер: как папайя (~47 см)', 'Көлөмү: папайядай (~47 см)', 'Size: like a papaya (~47 cm)');
    return _t('Размер: как арбуз (~50 см)', 'Көлөмү: дарбыздай (~50 см)', 'Size: like a watermelon (~50 cm)');
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
        title: Text(_t('Беременность', 'Кош бойлуулук', 'Pregnancy'), style: AppTypography.screenTitle(palette.fg)),
        actions: [
          IconButton(icon: Icon(Icons.tune, color: palette.secondary), onPressed: _openSetup),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_t('Неделя ${status.week}', '${status.week}-жума', 'Week ${status.week}'), style: TextStyle(color: AppColors.rose, fontSize: 28, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                _t(
                  '${status.trimester}-й триместр · до даты ${status.daysUntilDue} дн.',
                  '${status.trimester}-триместр · ${status.daysUntilDue} күн калды',
                  'Trimester ${status.trimester} · ${status.daysUntilDue} days until due date',
                ),
                style: AppTypography.caption(palette.secondary),
              ),
              const SizedBox(height: 12),
              Text(
                _t('Нагрузка ${status.strainMin.toStringAsFixed(0)}–${status.strainMax.toStringAsFixed(0)}', 'Жүктөм ${status.strainMin.toStringAsFixed(0)}–${status.strainMax.toStringAsFixed(0)}', 'Strain ${status.strainMin.toStringAsFixed(0)}–${status.strainMax.toStringAsFixed(0)}'),
                style: AppTypography.bodySemibold(palette.fg),
              ),
              const SizedBox(height: 6),
              Text(AppLocaleNotifier.isKyrgyz ? status.trainingKy : status.trainingRu, style: AppTypography.caption(palette.secondary).copyWith(height: 1.35)),
              const SizedBox(height: 8),
              Text(AppLocaleNotifier.isKyrgyz ? status.bodyKy : status.bodyRu, style: AppTypography.caption(palette.fg).copyWith(height: 1.35)),
              const SizedBox(height: 8),
              Text(_babySize(status.week), style: AppTypography.caption(palette.secondary)),
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
              Text(_t('Сегодня', 'Бүгүн', 'Today'), style: AppTypography.bodySemibold(palette.fg)),
              const SizedBox(height: 8),
              Text('${_t('Энергия', 'Энергия', 'Energy')} ${_log.energy}/5', style: AppTypography.caption(palette.secondary)),
              Slider(value: _log.energy.toDouble(), min: 1, max: 5, divisions: 4, activeColor: AppColors.sage, onChanged: (v) => setState(() => _log = PregnancyDayLog(energy: v.round(), nausea: _log.nausea, kicks: _log.kicks, note: _note.text))),
              Text('${_t('Тошнота', 'Жүрөк айлануу', 'Nausea')} ${_log.nausea}/3', style: AppTypography.caption(palette.secondary)),
              Slider(value: _log.nausea.toDouble(), min: 0, max: 3, divisions: 3, activeColor: AppColors.rose, onChanged: (v) => setState(() => _log = PregnancyDayLog(energy: _log.energy, nausea: v.round(), kicks: _log.kicks, note: _note.text))),
              if (status.week >= 28) ...[
                Text('${_t('Шевеления', 'Кыймыл', 'Kicks')} ${_log.kicks}', style: AppTypography.caption(palette.secondary)),
                Row(children: [
                  IconButton(onPressed: () => setState(() => _log = PregnancyDayLog(energy: _log.energy, nausea: _log.nausea, kicks: (_log.kicks - 1).clamp(0, 99), note: _note.text)), icon: Icon(Icons.remove_circle_outline)),
                  Text('${_log.kicks}', style: AppTypography.metricValue(palette.fg)),
                  IconButton(onPressed: () => setState(() => _log = PregnancyDayLog(energy: _log.energy, nausea: _log.nausea, kicks: _log.kicks + 1, note: _note.text)), icon: Icon(Icons.add_circle_outline)),
                ]),
              ],
              Text('${_t('Вода', 'Суу', 'Water')} ${_log.waterGlasses} ${_t('стак.', 'ст.', 'glasses')}', style: AppTypography.caption(palette.secondary)),
              Slider(value: _log.waterGlasses.toDouble().clamp(0, 12), min: 0, max: 12, divisions: 12, activeColor: AppColors.sleepBlue, onChanged: (v) => setState(() => _log = _log.copyWith(waterGlasses: v.round(), note: _note.text))),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_t('Витамины сегодня', 'Бүгүнкү витамин', 'Vitamins today'), style: TextStyle(color: palette.fg, fontSize: 14)),
                value: _log.vitamins,
                onChanged: (v) => setState(() => _log = _log.copyWith(vitamins: v, note: _note.text)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_t('Половой акт', 'Жыныстык акт', 'Intercourse'), style: TextStyle(color: palette.fg, fontSize: 14)),
                secondary: Icon(_log.intercourse ? Icons.favorite : Icons.favorite_border, color: AppColors.rose),
                value: _log.intercourse,
                onChanged: (v) => setState(() => _log = _log.copyWith(intercourse: v, note: _note.text)),
              ),
              TextField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(hintText: _t('Вес, кг', 'Салмак, кг', 'Weight, kg')),
                onChanged: (s) => _log = _log.copyWith(weightKg: double.tryParse(s.replaceAll(',', '.')), note: _note.text),
              ),
              const SizedBox(height: 8),
              TextField(controller: _note, maxLines: 2, decoration: InputDecoration(hintText: _t('Схватки, визит, самочувствие', 'Белги', 'Notes, symptoms, wellness'))),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveLog,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white, elevation: 0),
                  child: Text(_t('Сохранить день', 'Күндү сактоо', 'Save day')),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Text(
            _t(
              'Это не медицинское приложение и не Flo. Решения по нагрузке — с врачом.',
              'Бул медициналык колдонмо эмес. Жүктөм боюнча чечимди дарыгер менен алыңыз.',
              'This is not medical advice or Flo. Consult your physician for training intensity.',
            ),
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
        title: Text(_t('Срок', 'Мөөнөт', 'Term'), style: TextStyle(color: AppColors.fg)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: due, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 300)));
              if (picked != null) due = picked;
            },
            child: Text(_t('Предполагаемые роды', 'Божомолдонгон төрөт', 'Estimated due date')),
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
            child: Text(_t('От первых месячных (LMP)', 'Акыркы этек кирден', 'From first day of LMP')),
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
            child: Text(_t('Выключить режим', 'Режимди өчүрүү', 'Disable mode')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final updated = _profile.copyWith(isPregnant: true, pregnancyDueDate: due, pregnancyLmpDate: PregnancyEngine.lmpFromDue(due));
              await UserProfileRepository.saveProfile(updated);
              if (mounted) setState(() => _profile = updated);
            },
            child: Text(_t('Сохранить', 'Сактоо', 'Save')),
          ),
        ],
      ),
    );
  }
}
