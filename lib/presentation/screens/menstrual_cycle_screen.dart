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
import '../widgets/kalkan_ui.dart';
import '../widgets/kalkan_chrome.dart';

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

  String _tr(String ru, String ky, String en) => AppLocaleNotifier.t(ru, ky, en);

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
        SnackBar(content: Text(_tr('День сохранён', 'Күн сакталды', 'Day saved'))),
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
      msg = _tr('Пришли на $shift дн. раньше. Календарь сдвинут.', '$shift күн эрте келди. Календарь жылды.', 'Started $shift days early. Calendar updated.');
    } else if (shift <= -2) {
      msg = _tr('Пришли на ${-shift} дн. позже. Календарь сдвинут.', '${-shift} күн кеч келди. Календарь жылды.', 'Started ${-shift} days late. Calendar updated.');
    } else {
      msg = _tr('Новый цикл. Календарь от этой даты.', 'Жаңы цикл ушул күндөн.', 'New cycle started. Calendar updated.');
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
        return _tr('Месячные', 'Этек кир', 'Menstrual');
      case HormonalCyclePhase.follicular:
        return _tr('Фолликулярная', 'Фолликулярдык', 'Follicular');
      case HormonalCyclePhase.ovulatory:
        return _tr('Овуляция', 'Овуляция', 'Ovulatory');
      case HormonalCyclePhase.luteal:
        return _tr('Лютеиновая', 'Лютеиндик', 'Luteal');
    }
  }

  String _moodLabel(String id) {
    switch (id) {
      case 'irritable':
        return _tr('Раздражение', 'Ачуулануу', 'Irritable');
      case 'anxious':
        return _tr('Тревога', 'Тынчсыздануу', 'Anxious');
      case 'energy':
        return _tr('Энергия', 'Энергия', 'Energetic');
      default:
        return _tr('Спокойно', 'Тынч', 'Calm');
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
          appBar: KalkanAppBar(
            eyebrow: _tr('ЖЕНСКОЕ ЗДОРОВЬЕ', 'АЯЛДАРДЫН ДЕН СООЛУГУ', "WOMEN'S HEALTH"),
            title: _tr('Цикл', 'Цикл', 'Cycle'),
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
              if (_profile.lastPeriodStartDate == null)
                KalkanCard(
                  padding: const EdgeInsets.all(16),
                  borderColor: AppColors.rose.withValues(alpha: 0.35),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.rose.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                            ),
                            child: const Icon(Icons.calendar_today_outlined, color: AppColors.rose, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _tr('БИОРИТМ СААТ-1', 'СААТ-1 БИОЫРГАГЫ', 'SAAT-1 BIORHYTHM'),
                                  style: AppTypography.eyebrow(palette.secondary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _tr('Цикл ещё не настроен', 'Цикл жөндөлө элек', 'Cycle Not Configured'),
                                  style: AppTypography.bodySemibold(palette.fg),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _tr(
                          'Укажите дату начала последних месячных. Без неё фазы цикла, окно овуляции и адаптивный Strain рассчитывать некорректно.',
                          'Акыркы этек кирдин күнүн белгилеңиз. Ансыз фазалар жана овуляция туура эмес эсептелет.',
                          'Please set the start date of your last period. Without it, cycle phases, ovulation window, and adaptive strain cannot be calculated correctly.',
                        ),
                        style: AppTypography.caption(palette.secondary).copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _markPeriodStarted(DateTime.now()),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.rose,
                                side: const BorderSide(color: AppColors.rose),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KalkanUi.controlRadius)),
                              ),
                              child: Text(_tr('Начались сегодня', 'Бүгүн башталды', 'Started Today')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: now.subtract(const Duration(days: 7)),
                                  firstDate: now.subtract(const Duration(days: 90)),
                                  lastDate: now,
                                );
                                if (picked != null) {
                                  await _markPeriodStarted(picked);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KalkanUi.controlRadius)),
                              ),
                              child: Text(_tr('Выбрать дату', 'Күндү тандоо', 'Pick Date')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                KalkanCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_phaseName(phase), style: AppTypography.screenTitle(color)),
                      const SizedBox(height: 4),
                      Text(
                        _tr('День $_selectedDay из $_length', '$_selectedDay-күн / $_length', 'Day $_selectedDay of $_length'),
                        style: AppTypography.caption(palette.secondary),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _forecast(palette, _tr('Следующие месячные', 'Кийинки этек кир', 'Next Period'), untilNext)),
                        const SizedBox(width: 8),
                        Expanded(child: _forecast(palette, _tr('Овуляция', 'Овуляция', 'Ovulation'), untilOvu)),
                      ]),
                      const SizedBox(height: 12),
                      Text(
                        '${_tr('Нагрузка сегодня', 'Бүгүнкү жүктөм', 'Today Strain')}  ${analysis.targetStrainMin.toStringAsFixed(0)}–${analysis.targetStrainMax.toStringAsFixed(1)}',
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
                    child: Text(_tr('Начались', 'Башталды', 'Started')),
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
                    child: Text(_tr('Закончились', 'Бүттү', 'Ended')),
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
                      ? _tr('Акт записан', 'Акт жазылды', 'Intercourse logged')
                      : _tr('Половой акт', 'Жыныстык акт', 'Intercourse')),
                ),
              ),
              const SizedBox(height: 16),
              _calendar(palette),
              const SizedBox(height: 16),
              _legend(palette),
              const SizedBox(height: 16),
              KalkanCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_tr('Дневник', 'Күндөлүк', 'Diary')}  ${_selectedDate.day}.${_selectedDate.month}',
                      style: AppTypography.bodySemibold(palette.fg),
                    ),
                    const SizedBox(height: 12),
                    Text(_tr('Выделения', 'Агым', 'Flow'), style: AppTypography.caption(palette.secondary)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _chip('none', _tr('Нет', 'Жок', 'None'), _flow == 'none', () => _setFlow('none')),
                      _chip('spotting', _tr('Мажущие', 'Маз', 'Spotting'), _flow == 'spotting', () => _setFlow('spotting')),
                      _chip('light', _tr('Скудные', 'Аз', 'Light'), _flow == 'light', () => _setFlow('light')),
                      _chip('medium', _tr('Средние', 'Орто', 'Medium'), _flow == 'medium', () => _setFlow('medium')),
                      _chip('heavy', _tr('Обильные', 'Көп', 'Heavy'), _flow == 'heavy', () => _setFlow('heavy')),
                    ]),
                    const SizedBox(height: 14),
                    Text('${_tr('Энергия', 'Энергия', 'Energy')}  $_energyScore/5', style: AppTypography.caption(palette.secondary)),
                    Slider(
                      value: _energyScore.toDouble(),
                      min: 1, max: 5, divisions: 4,
                      activeColor: AppColors.sage,
                      onChanged: (v) => setState(() => _energyScore = v.round()),
                      onChangeEnd: (_) => _saveDay(),
                    ),
                    Text('${_tr('Спазмы', 'Спазм', 'Cramps')}  $_crampLevel/3', style: AppTypography.caption(palette.secondary)),
                    Slider(
                      value: _crampLevel.toDouble(),
                      min: 0, max: 3, divisions: 3,
                      activeColor: AppColors.rose,
                      onChanged: (v) => setState(() => _crampLevel = v.round()),
                      onChangeEnd: (_) => _saveDay(),
                    ),
                    Text(_tr('Настроение', 'Маанай', 'Mood'), style: AppTypography.caption(palette.secondary)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final id in ['calm', 'irritable', 'anxious', 'energy'])
                        _chip(id, _moodLabel(id), _mood == id, () async {
                          setState(() => _mood = id);
                          await _saveDay();
                        }),
                    ]),
                    const SizedBox(height: 12),
                    Text(_tr('Симптомы', 'Белгилер', 'Symptoms'), style: AppTypography.caption(palette.secondary)),
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
                      decoration: InputDecoration(hintText: _tr('Заметка', 'Белги', 'Note')),
                      onEditingComplete: () => _saveDay(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _saveDay(toast: true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white, elevation: 0),
                        child: Text(_tr('Сохранить', 'Сактоо', 'Save')),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Переход в режим беременности
              KalkanCard(
                onTap: _enablePregnancyMode,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.rose.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                      ),
                      child: const Icon(Icons.favorite, color: AppColors.rose, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tr('Режим беременности', 'Кош бойлуулук режими', 'Pregnancy Mode'),
                            style: AppTypography.bodySemibold(palette.fg),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _tr(
                              'Включить трекинг триместров и адаптацию нагрузки',
                              'Триместрлерди жана жүктөмдү көзөмөлдөө',
                              'Enable trimester tracking and load adaptation',
                            ),
                            style: AppTypography.caption(palette.secondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: palette.muted),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<String> _symptomList() {
    switch (AppLocaleNotifier.current) {
      case AppLanguage.kyrgyz:
        return const ['Спазм', 'Баш оору', 'Шишик', 'Уйкусуздук', 'Тамакка умтулуу', 'Көкүрөк оорусу'];
      case AppLanguage.english:
        return const ['Cramps', 'Headache', 'Bloating', 'Insomnia', 'Cravings', 'Breast tenderness'];
      case AppLanguage.russian:
        return const ['Спазмы', 'Головная боль', 'Отёк', 'Бессонница', 'Тяга к еде', 'Боль в груди'];
    }
  }

  Future<void> _setFlow(String v) async {
    setState(() => _flow = v);
    await _saveDay();
  }

  Widget _forecast(KalkanColors palette, String label, int days) {
    final text = days == 0
        ? _tr('сегодня', 'бүгүн', 'today')
        : days > 0
            ? _tr('через $days дн.', '$days күндон кийин', 'in $days d.')
            : _tr('${-days} дн. назад', '${-days} күн мурун', '${-days} d. ago');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: palette.raised, borderRadius: BorderRadius.circular(KalkanUi.controlRadius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTypography.caption(palette.secondary)),
        const SizedBox(height: 4),
        Text(text, style: AppTypography.bodySemibold(palette.fg)),
      ]),
    );
  }

  Widget _legend(KalkanColors palette) {
    return Wrap(spacing: 12, runSpacing: 6, children: [
      _dot(AppColors.rose, _tr('Месячные', 'Этек кир', 'Period')),
      _dot(AppColors.sage, _tr('Фолликулярная', 'Фолликулярдык', 'Follicular')),
      _dot(AppColors.amber, _tr('Овуляция', 'Овуляция', 'Ovulation')),
      _dot(AppColors.strainBlue, _tr('Лютеиновая', 'Лютеиндик', 'Luteal')),
    ]);
  }

  Widget _dot(Color c, String t) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(t, style: AppTypography.caption(KalkanColors.of(context).secondary)),
    ]);
  }

  Widget _calendar(KalkanColors palette) {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final lead = (first.weekday + 6) % 7; // Monday first
    final months = AppLocaleNotifier.pick(
      const ['Январь','Февраль','Март','Апрель','Май','Июнь','Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь'],
      const ['Үчтүн айы','Бирдин айы','Жалган куран','Чын куран','Бугу','Кулжа','Теке','Баш оона','Аяк оона','Тогуздун айы','Жетинин айы','Бештин айы'],
      const ['January','February','March','April','May','June','July','August','September','October','November','December'],
    );
    final week = AppLocaleNotifier.pick(
      const ['Пн','Вт','Ср','Чт','Пт','Сб','Вс'],
      const ['Дш','Шш','Шр','Бш','Жм','Иш','Жк'],
      const ['Mo','Tu','We','Th','Fr','Sa','Su'],
    );

    return KalkanCard(
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
                      Text('$day', style: AppTypography.bodyMuted(palette.fg).copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
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
          borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
          border: Border.all(color: on ? AppColors.sage : palette.hairline, width: KalkanUi.hairline),
        ),
        child: Text(label, style: AppTypography.bodyMuted(palette.fg).copyWith(fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
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
        padding: const EdgeInsets.fromLTRB(KalkanUi.pagePadding, 16, KalkanUi.pagePadding, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tr('Пригласить партнёра', 'Өнөктөштү чакыруу', 'Invite Partner'), style: AppTypography.screenTitle(AppColors.fg)),
            const SizedBox(height: 8),
            Text(
              _tr(
                'Передайте этот код партнёру. В его приложении ваши имя и фаза определятся автоматически.',
                'Бул кодду өнөктөшүңүзгө бериңиз. Анын колдонмосунда атыңыз жана фазаңыз автоматтык түрдө чыгат.',
                'Share this code with your partner. Your name and phase will be detected automatically.',
              ),
              style: AppTypography.bodyMuted(AppColors.secondary),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.raised,
                borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                border: Border.all(color: AppColors.hairline, width: KalkanUi.hairline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _partnerInviteCode,
                      style: AppTypography.metric(AppColors.fg).copyWith(letterSpacing: 1.2),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, size: 18, color: AppColors.sage),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _partnerInviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_tr('Код скопирован: $_partnerInviteCode', 'Код көчүрүлдү: $_partnerInviteCode', 'Code copied: $_partnerInviteCode')),
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
                        content: Text(_tr('Код скопирован: $_partnerInviteCode', 'Код көчүрүлдү: $_partnerInviteCode', 'Code copied: $_partnerInviteCode')),
                        backgroundColor: AppColors.surface,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage, foregroundColor: Colors.white, elevation: 0),
                  label: Text(_tr('Скопировать код', 'Кодду көчүрүү', 'Copy Code')),
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
          title: Text(_tr('Настройки цикла', 'Цикл жөндөөлөрү', 'Cycle Settings'), style: AppTypography.screenTitle(AppColors.fg)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_tr('Длина цикла', 'Цикл узундугу', 'Cycle Length')}: $length', style: AppTypography.body(AppColors.secondary)),
              Slider(value: length.toDouble(), min: 21, max: 40, divisions: 19, activeColor: AppColors.sage, onChanged: (v) => setDialog(() => length = v.round())),
              Text('${_tr('Длительность месячных', 'Этек кирдин узактыгы', 'Period Duration')}: $periodLen', style: AppTypography.body(AppColors.secondary)),
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
                child: Text('${_tr('Последние начались', 'Акыркы башталышы', 'Last started')} ${startDate.day}.${startDate.month}'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(_tr('Отмена', 'Жок', 'Cancel'))),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final updated = _profile.copyWith(cycleLengthDays: length, periodDurationDays: periodLen, lastPeriodStartDate: startDate);
                await UserProfileRepository.saveProfile(updated);
                setState(() => _profile = updated);
              },
              child: Text(_tr('Сохранить', 'Сактоо', 'Save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enablePregnancyMode() async {
    final lmp = _profile.lastPeriodStartDate ?? DateTime.now().subtract(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: lmp,
      firstDate: DateTime.now().subtract(const Duration(days: 300)),
      lastDate: DateTime.now(),
      helpText: _tr('Первый день последних месячных (LMP)', 'Акыркы этек кирдин биринчи күнү', 'First day of last menstrual period (LMP)'),
    );
    if (picked != null) {
      final due = picked.add(const Duration(days: 280));
      final updated = _profile.copyWith(
        isPregnant: true,
        pregnancyLmpDate: picked,
        pregnancyDueDate: due,
      );
      await UserProfileRepository.saveProfile(updated);
      if (mounted) {
        setState(() => _profile = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surface,
            content: Text(
              _tr('Режим беременности включён', 'Кош бойлуулук режими күйгүзүлдү', 'Pregnancy mode enabled'),
              style: AppTypography.bodySemibold(AppColors.fg),
            ),
          ),
        );
      }
    }
  }
}
