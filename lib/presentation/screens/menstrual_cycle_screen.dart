import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_typography.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/partner_cycle_repository.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../data/services/cloud_sync_service.dart';
import '../../domain/intelligence/menstrual_cycle_engine.dart';
import '../../domain/models/telemetry.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/glass_card.dart';

class MenstrualCycleScreen extends StatefulWidget {
  final UteBleBridge bleBridge;
  const MenstrualCycleScreen({super.key, required this.bleBridge});

  @override
  State<MenstrualCycleScreen> createState() => _MenstrualCycleScreenState();
}

class _MenstrualCycleScreenState extends State<MenstrualCycleScreen> {
  UserProfile _profile = const UserProfile(gender: Gender.female);
  late BleTelemetry _telemetry;
  StreamSubscription<BleTelemetry>? _sub;
  DateTime _selectedDate = MenstrualCycleEngine.dateOnly(DateTime.now());
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _energyScore = 3;
  int _crampLevel = 0;
  String _mood = 'calm';
  String _flow = 'none';
  final Set<String> _selectedSymptoms = <String>{};
  final TextEditingController _noteController = TextEditingController();
  final Set<String> _loggedDates = <String>{};
  final Set<String> _sexDates = <String>{};
  bool _sexToday = false;
  bool _partnerLinked = false;
  String _partnerInviteCode = 'KLK-CYC-9281';

  bool get _ru => AppLocaleNotifier.current != AppLanguage.kyrgyz;
  int get _length => _profile.cycleLengthDays > 0 ? _profile.cycleLengthDays : 28;
  int get _periodLen => _profile.periodDurationDays > 0 ? _profile.periodDurationDays : 5;
  int get _selectedDay => MenstrualCycleEngine.cycleDayForDate(
        _selectedDate,
        _profile.lastPeriodStartDate,
        cycleLength: _length,
      );

  @override
  void initState() {
    super.initState();
    _telemetry = widget.bleBridge.currentTelemetry;
    _load();
    _sub = widget.bleBridge.telemetryStream.listen((data) {
      if (mounted) setState(() => _telemetry = data);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final p = await UserProfileRepository.loadProfile();
    final prefs = await SharedPreferences.getInstance();
    final partner = await PartnerCycleRepository.loadPartnerCycle();
    final marks = <String>{};
    final sex = <String>{};
    for (final k in prefs.getKeys()) {
      if (k.startsWith('cycle_log_') && k.endsWith('_mark')) {
        marks.add(k.replaceFirst('cycle_log_', '').replaceAll('_mark', ''));
      }
      if (k.startsWith('cycle_log_') && k.endsWith('_sex') && prefs.getBool(k) == true) {
        sex.add(k.replaceFirst('cycle_log_', '').replaceAll('_sex', ''));
      }
    }
    final cloudCode = await CloudSyncService.publishCycleInvite();
    if (!mounted) return;
    setState(() {
      _profile = p.copyWith(gender: Gender.female);
      _partnerInviteCode = cloudCode;
      _loggedDates.addAll(marks);
      _sexDates
        ..clear()
        ..addAll(sex);
      if (partner.isLinked) _partnerLinked = true;
    });
    await _loadDay(_selectedDate);
  }

  Future<void> _loadDay(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dateKey(date);
    final cycleDay = MenstrualCycleEngine.cycleDayForDate(date, _profile.lastPeriodStartDate, cycleLength: _length);
    setState(() {
      _selectedDate = MenstrualCycleEngine.dateOnly(date);
      _flow = prefs.getString('cycle_log_${key}_flow') ??
          prefs.getString('cycle_flow_day_$cycleDay') ??
          (cycleDay <= _periodLen ? 'medium' : 'none');
      _energyScore = prefs.getInt('cycle_log_${key}_energy') ?? prefs.getInt('cycle_energy_day_$cycleDay') ?? 3;
      _crampLevel = prefs.getInt('cycle_log_${key}_cramps') ?? prefs.getInt('cycle_cramps_day_$cycleDay') ?? 0;
      _mood = prefs.getString('cycle_log_${key}_mood') ?? 'calm';
      _selectedSymptoms
        ..clear()
        ..addAll(prefs.getStringList('cycle_log_${key}_symptoms') ?? const <String>[]);
      _noteController.text = prefs.getString('cycle_log_${key}_note') ?? '';
      _sexToday = prefs.getBool('cycle_log_${key}_sex') ?? false;
    });
  }

  Future<void> _saveDay({bool toast = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dateKey(_selectedDate);
    final day = _selectedDay;
    await prefs.setBool('cycle_log_${key}_mark', true);
    await prefs.setString('cycle_log_${key}_flow', _flow);
    await prefs.setInt('cycle_log_${key}_energy', _energyScore);
    await prefs.setInt('cycle_log_${key}_cramps', _crampLevel);
    await prefs.setString('cycle_log_${key}_mood', _mood);
    await prefs.setStringList('cycle_log_${key}_symptoms', _selectedSymptoms.toList());
    await prefs.setString('cycle_log_${key}_note', _noteController.text.trim());
    await prefs.setBool('cycle_log_${key}_sex', _sexToday);
    if (_sexToday) {
      _sexDates.add(key);
    } else {
      _sexDates.remove(key);
    }
    await prefs.setString('cycle_flow_day_$day', _flow);
    await PartnerCycleRepository.syncFromFemaleProfile(
      _profile,
      currentCycleDay: day,
      energyScore: _energyScore,
      mood: _moodLabel(_mood),
      flow: _flow,
      symptoms: _selectedSymptoms.toList(),
      note: _noteController.text.trim(),
      skinTempDeviation: _telemetry.skinTempDeviation,
    );
    setState(() => _loggedDates.add(key));
    if (toast && mounted) {
      CircaHaptics.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_ru ? 'День сохранён' : 'Күн сакталды')),
      );
    }
  }

  Future<void> _markPeriodStarted(DateTime date) async {
    CircaHaptics.heavyAlert();
    final predicted = MenstrualCycleEngine.nextPeriodStart(_profile.lastPeriodStartDate, cycleLength: _length);
    final day = MenstrualCycleEngine.dateOnly(date);
    final shift = predicted.difference(day).inDays; // >0 early, <0 late
    final updated = _profile.copyWith(lastPeriodStartDate: day, cycleDay: 1);
    await UserProfileRepository.saveProfile(updated);
    setState(() {
      _profile = updated;
      _flow = 'medium';
    });
    await _loadDay(date);
    await _saveDay();
    if (!mounted) return;
    String msg;
    if (shift >= 2) {
      msg = _ru ? 'Пришли на $shift дн. раньше. Календарь сдвинут.' : '$shift күн эрте келди. Календарь жылды.';
    } else if (shift <= -2) {
      msg = _ru ? 'Пришли на ${-shift} дн. позже. Календарь сдвинут.' : '${-shift} күн кеч келди. Календарь жылды.';
    } else {
      msg = _ru ? 'Новый цикл. Календарь от этой даты.' : 'Жаңы цикл ушул күндөн.';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _phaseColor(HormonalCyclePhase phase) {
    switch (phase) {
      case HormonalCyclePhase.menstrual:
        return AppColors.rose;
      case HormonalCyclePhase.follicular:
        return AppColors.sage;
      case HormonalCyclePhase.ovulatory:
        return AppColors.amber;
      case HormonalCyclePhase.luteal:
        return AppColors.strainBlue;
    }
  }

  String _phaseName(HormonalCyclePhase phase) {
    switch (phase) {
      case HormonalCyclePhase.menstrual:
        return _ru ? 'Месячные' : 'Этек кир';
      case HormonalCyclePhase.follicular:
        return _ru ? 'Фолликулярная' : 'Фолликулярдык';
      case HormonalCyclePhase.ovulatory:
        return _ru ? 'Овуляция' : 'Овуляция';
      case HormonalCyclePhase.luteal:
        return _ru ? 'Лютеиновая' : 'Лютеиндик';
    }
  }

  String _moodLabel(String id) {
    switch (id) {
      case 'irritable':
        return _ru ? 'Раздражение' : 'Ачуулануу';
      case 'anxious':
        return _ru ? 'Тревога' : 'Тынчсыздануу';
      case 'energy':
        return _ru ? 'Энергия' : 'Энергия';
      default:
        return _ru ? 'Спокойно' : 'Тынч';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        final analysis = MenstrualCycleEngine.analyze(
          telemetry: _telemetry,
          profile: _profile,
          language: language,
        );
        final phase = MenstrualCycleEngine.determinePhase(
          _selectedDay,
          cycleLength: _length,
          periodDuration: _periodLen,
        );
        final color = _phaseColor(phase);
        final next = MenstrualCycleEngine.nextPeriodStart(_profile.lastPeriodStartDate, cycleLength: _length);
        final ovu = MenstrualCycleEngine.predictedOvulation(_profile.lastPeriodStartDate, cycleLength: _length);
        final untilNext = MenstrualCycleEngine.daysUntil(next);
        final untilOvu = MenstrualCycleEngine.daysUntil(ovu);

        return Scaffold(
          backgroundColor: palette.bg,
          appBar: AppBar(
            backgroundColor: palette.bg,
            elevation: 0,
            title: Text(_ru ? 'Цикл' : 'Цикл', style: AppTypography.screenTitle(palette.fg)),
            actions: [
              IconButton(
                icon: Icon(_partnerLinked ? Icons.favorite : Icons.favorite_border, color: AppColors.rose, size: 20),
                onPressed: _openPartnerSheet,
              ),
              IconButton(
                icon: Icon(Icons.tune, color: palette.secondary, size: 20),
                onPressed: _openSettings,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_phaseName(phase), style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      _ru ? 'День $_selectedDay из $_length' : '$_selectedDay-күн / $_length',
                      style: AppTypography.caption(palette.secondary),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _forecast(palette, _ru ? 'Следующие месячные' : 'Кийинки этек кир', untilNext)),
                      const SizedBox(width: 8),
                      Expanded(child: _forecast(palette, _ru ? 'Овуляция' : 'Овуляция', untilOvu)),
                    ]),
                    const SizedBox(height: 12),
                    Text(
                      '${_ru ? 'Нагрузка сегодня' : 'Бүгүнкү жүктөм'}  ${analysis.targetStrainMin.toStringAsFixed(0)}–${analysis.targetStrainMax.toStringAsFixed(1)}',
                      style: AppTypography.bodySemibold(palette.fg),
                    ),
                    const SizedBox(height: 4),
                    Text(analysis.trainingDirective, style: AppTypography.caption(palette.secondary).copyWith(height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _markPeriodStarted(_selectedDate),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rose,
                      side: const BorderSide(color: AppColors.rose),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(_ru ? 'Начались' : 'Башталды'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      setState(() => _flow = 'none');
                      await _saveDay(toast: true);
                    },
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: Text(_ru ? 'Закончились' : 'Бүттү'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    setState(() => _sexToday = !_sexToday);
                    await _saveDay(toast: true);
                  },
                  icon: Icon(_sexToday ? Icons.favorite : Icons.favorite_border, color: AppColors.rose, size: 18),
                  label: Text(_sexToday
                      ? (_ru ? 'Акт записан' : 'Акт жазылды')
                      : (_ru ? 'Половой акт' : 'Жыныстык акт')),
                ),
              ),
              const SizedBox(height: 16),
              _calendar(palette),
              const SizedBox(height: 16),
              _legend(palette),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _ru
                          ? 'Дневник  ${_selectedDate.day}.${_selectedDate.month}'
                          : 'Күндөлүк  ${_selectedDate.day}.${_selectedDate.month}',
                      style: AppTypography.bodySemibold(palette.fg),
                    ),
                    const SizedBox(height: 12),
                    Text(_ru ? 'Выделения' : 'Агым', style: AppTypography.caption(palette.secondary)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _chip('none', _ru ? 'Нет' : 'Жок', _flow == 'none', () => _setFlow('none')),
                      _chip('spotting', _ru ? 'Мажущие' : 'Маз', _flow == 'spotting', () => _setFlow('spotting')),
                      _chip('light', _ru ? 'Скудные' : 'Аз', _flow == 'light', () => _setFlow('light')),
                      _chip('medium', _ru ? 'Средние' : 'Орто', _flow == 'medium', () => _setFlow('medium')),
                      _chip('heavy', _ru ? 'Обильные' : 'Көп', _flow == 'heavy', () => _setFlow('heavy')),
                    ]),
                    const SizedBox(height: 14),
                    Text('${_ru ? 'Энергия' : 'Энергия'}  $_energyScore/5', style: AppTypography.caption(palette.secondary)),
                    Slider(
                      value: _energyScore.toDouble(),
                      min: 1, max: 5, divisions: 4,
                      activeColor: AppColors.sage,
                      onChanged: (v) => setState(() => _energyScore = v.round()),
                      onChangeEnd: (_) => _saveDay(),
                    ),
                    Text('${_ru ? 'Спазмы' : 'Спазм'}  $_crampLevel/3', style: AppTypography.caption(palette.secondary)),
                    Slider(
                      value: _crampLevel.toDouble(),
                      min: 0, max: 3, divisions: 3,
                      activeColor: AppColors.rose,
                      onChanged: (v) => setState(() => _crampLevel = v.round()),
                      onChangeEnd: (_) => _saveDay(),
                    ),
                    Text(_ru ? 'Настроение' : 'Маанай', style: AppTypography.caption(palette.secondary)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final id in ['calm', 'irritable', 'anxious', 'energy'])
                        _chip(id, _moodLabel(id), _mood == id, () async {
                          setState(() => _mood = id);
                          await _saveDay();
                        }),
                    ]),
                    const SizedBox(height: 12),
                    Text(_ru ? 'Симптомы' : 'Белгилер', style: AppTypography.caption(palette.secondary)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final s in _symptomList())
                        _chip(s, s, _selectedSymptoms.contains(s), () async {
                          setState(() {
                            if (_selectedSymptoms.contains(s)) {
                              _selectedSymptoms.remove(s);
                            } else {
                              _selectedSymptoms.add(s);
                            }
                          });
                          await _saveDay();
                        }),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      maxLines: 2,
                      decoration: InputDecoration(hintText: _ru ? 'Заметка' : 'Белги'),
                      onEditingComplete: () => _saveDay(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _saveDay(toast: true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white, elevation: 0),
                        child: Text(_ru ? 'Сохранить' : 'Сактоо'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<String> _symptomList() => _ru
      ? ['Спазмы', 'Головная боль', 'Отёк', 'Бессонница', 'Тяга к еде', 'Боль в груди']
      : ['Спазм', 'Баш оору', 'Шишик', 'Уйкусуздук', 'Тамакка умтулуу', 'Көкүрөк оорусу'];

  Future<void> _setFlow(String v) async {
    setState(() => _flow = v);
    await _saveDay();
  }

  Widget _forecast(KalkanColors palette, String label, int days) {
    final text = days == 0
        ? (_ru ? 'сегодня' : 'бүгүн')
        : days > 0
            ? (_ru ? 'через $days дн.' : '$days күндон кийин')
            : (_ru ? '${-days} дн. назад' : '${-days} күн мурун');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: palette.raised, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTypography.caption(palette.secondary)),
        const SizedBox(height: 4),
        Text(text, style: AppTypography.bodySemibold(palette.fg)),
      ]),
    );
  }

  Widget _legend(KalkanColors palette) {
    return Wrap(spacing: 12, runSpacing: 6, children: [
      _dot(AppColors.rose, _ru ? 'Месячные' : 'Этек кир'),
      _dot(AppColors.sage, _ru ? 'Фолликулярная' : 'Фолликулярдык'),
      _dot(AppColors.amber, _ru ? 'Овуляция' : 'Овуляция'),
      _dot(AppColors.strainBlue, _ru ? 'Лютеиновая' : 'Лютеиндик'),
    ]);
  }

  Widget _dot(Color c, String t) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(t, style: TextStyle(color: KalkanColors.of(context).secondary, fontSize: 12)),
    ]);
  }

  Widget _calendar(KalkanColors palette) {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final lead = (first.weekday + 6) % 7; // Monday first
    final months = _ru
        ? ['Январь','Февраль','Март','Апрель','Май','Июнь','Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь']
        : ['Үчтүн айы','Бирдин айы','Жалган куран','Чын куран','Бугу','Кулжа','Теке','Баш оона','Аяк оона','Тогуздун айы','Жетинин айы','Бештин айы'];
    final week = _ru ? ['Пн','Вт','Ср','Чт','Пт','Сб','Вс'] : ['Дш','Шш','Шр','Бш','Жм','Иш','Жк'];

    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
                icon: Icon(Icons.chevron_left, color: palette.secondary),
              ),
              Expanded(
                child: Text(
                  '${months[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySemibold(palette.fg),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1)),
                icon: Icon(Icons.chevron_right, color: palette.secondary),
              ),
            ],
          ),
          Row(children: [for (final d in week) Expanded(child: Text(d, textAlign: TextAlign.center, style: AppTypography.caption(palette.muted)))]),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lead + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
            itemBuilder: (_, i) {
              if (i < lead) return const SizedBox.shrink();
              final day = i - lead + 1;
              final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
              final cycleDay = MenstrualCycleEngine.cycleDayForDate(date, _profile.lastPeriodStartDate, cycleLength: _length);
              final phase = MenstrualCycleEngine.determinePhase(cycleDay, cycleLength: _length, periodDuration: _periodLen);
              final selected = _dateKey(date) == _dateKey(_selectedDate);
              final today = _dateKey(date) == _dateKey(DateTime.now());
              final logged = _loggedDates.contains(_dateKey(date));
              return GestureDetector(
                onTap: () => _loadDay(date),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? _phaseColor(phase).withValues(alpha: 0.22) : palette.raised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: selected ? _phaseColor(phase) : (today ? palette.lineStrong : Colors.transparent)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day', style: TextStyle(color: palette.fg, fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
                      const SizedBox(height: 2),
                      if (_sexDates.contains(_dateKey(date)))
                        Icon(Icons.favorite, size: 9, color: AppColors.rose)
                      else
                        Container(width: 5, height: 5, decoration: BoxDecoration(color: _phaseColor(phase), shape: BoxShape.circle)),
                      if (logged && !_sexDates.contains(_dateKey(date)))
                        Container(margin: const EdgeInsets.only(top: 2), width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.amber, shape: BoxShape.circle)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _chip(String key, String label, bool on, VoidCallback tap) {
    final palette = KalkanColors.of(context);
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: on ? AppColors.sage.withValues(alpha: 0.16) : palette.raised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? AppColors.sage : palette.hairline),
        ),
        child: Text(label, style: TextStyle(color: palette.fg, fontSize: 12, fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  Future<void> _openPartnerSheet() async {
    final code = await CloudSyncService.publishCycleInvite();
    if (mounted) {
      setState(() => _partnerInviteCode = code);
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_ru ? 'Пригласить партнёра' : 'Өнөктөштү чакыруу', style: TextStyle(color: AppColors.fg, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              _ru
                  ? 'Передайте этот код партнёру. В его приложении ваши имя и фаза определятся автоматически.'
                  : 'Бул кодду өнөктөшүңүзгө бериңиз. Анын колдонмосунда атыңыз жана фазаңыз автоматтык түрдө чыгат.',
              style: TextStyle(color: AppColors.secondary, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.raised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _partnerInviteCode,
                      style: TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, size: 18, color: AppColors.sage),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _partnerInviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_ru ? 'Код скопирован: $_partnerInviteCode' : 'Код көчүрүлдү: $_partnerInviteCode'),
                          backgroundColor: AppColors.surface,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _partnerInviteCode));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_ru ? 'Код скопирован: $_partnerInviteCode' : 'Код көчүрүлдү: $_partnerInviteCode'),
                        backgroundColor: AppColors.surface,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white, elevation: 0),
                  label: Text(_ru ? 'Скопировать код' : 'Кодду көчүрүү'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _openSettings() {
    int length = _length;
    int periodLen = _periodLen;
    DateTime startDate = _profile.lastPeriodStartDate ?? DateTime.now().subtract(const Duration(days: 14));
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(_ru ? 'Настройки цикла' : 'Цикл жөндөөлөрү', style: TextStyle(color: AppColors.fg)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_ru ? 'Длина цикла' : 'Цикл узундугу'}: $length', style: TextStyle(color: AppColors.secondary)),
              Slider(value: length.toDouble(), min: 21, max: 40, divisions: 19, activeColor: AppColors.sage, onChanged: (v) => setDialog(() => length = v.round())),
              Text('${_ru ? 'Длительность месячных' : 'Этек кирдин узактыгы'}: $periodLen', style: TextStyle(color: AppColors.secondary)),
              Slider(value: periodLen.toDouble(), min: 2, max: 10, divisions: 8, activeColor: AppColors.rose, onChanged: (v) => setDialog(() => periodLen = v.round())),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 90)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setDialog(() => startDate = picked);
                },
                child: Text(_ru ? 'Последние начались ${startDate.day}.${startDate.month}' : 'Акыркы башталышы ${startDate.day}.${startDate.month}'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(_ru ? 'Отмена' : 'Жок')),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final updated = _profile.copyWith(cycleLengthDays: length, periodDurationDays: periodLen, lastPeriodStartDate: startDate);
                await UserProfileRepository.saveProfile(updated);
                setState(() => _profile = updated);
              },
              child: Text(_ru ? 'Сохранить' : 'Сактоо'),
            ),
          ],
        ),
      ),
    );
  }
}
