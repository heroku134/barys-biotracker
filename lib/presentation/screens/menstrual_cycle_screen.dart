import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/partner_cycle_repository.dart';
import '../../data/storage/user_profile_repository.dart';
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
  int _selectedDay = 14;

  // Полноценный дневник отметок дня
  int _energyScore = 4; // 1..5
  int _crampLevel = 1; // 0..3
  String _mood = 'Спокойствие';
  String _flow = 'none'; // 'none', 'spotting', 'light', 'medium', 'heavy'
  final Set<String> _selectedSymptoms = <String>{};
  final TextEditingController _noteController = TextEditingController();
  final Set<int> _daysWithMarks = <int>{};

  // Синхронизация с партнером
  bool _partnerLinked = false;
  String _partnerName = 'Алихан';
  String _partnerInviteCode = 'KLK-CYC-9281';

  @override
  void initState() {
    super.initState();
    _telemetry = widget.bleBridge.currentTelemetry;
    _loadProfileAndSymptoms();

    widget.bleBridge.telemetryStream.listen((data) {
      if (mounted) setState(() => _telemetry = data);
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileAndSymptoms() async {
    final p = await UserProfileRepository.loadProfile();
    final prefs = await SharedPreferences.getInstance();
    final currentDay = MenstrualCycleEngine.calculateCurrentCycleDay(
      p.lastPeriodStartDate,
      cycleLength: p.cycleLengthDays > 0 ? p.cycleLengthDays : 28,
    );

    final partnerData = await PartnerCycleRepository.loadPartnerCycle();

    final marks = <int>{};
    final totalDays = p.cycleLengthDays > 0 ? p.cycleLengthDays : 28;
    for (int d = 1; d <= totalDays; d++) {
      if (prefs.containsKey('cycle_mark_day_$d') ||
          prefs.containsKey('cycle_flow_day_$d') ||
          prefs.containsKey('cycle_energy_day_$d')) {
        marks.add(d);
      }
    }

    if (mounted) {
      setState(() {
        _profile = p;
        _selectedDay = currentDay;
        _daysWithMarks.addAll(marks);
        _partnerLinked = partnerData.isLinked;
        _partnerName = partnerData.partnerName.isNotEmpty ? partnerData.partnerName : 'Алихан';
        _partnerInviteCode = partnerData.partnerCode.isNotEmpty ? partnerData.partnerCode : 'KLK-CYC-9281';
      });
      await _loadDayLog(currentDay);
    }
  }

  Future<void> _loadDayLog(int day) async {
    final prefs = await SharedPreferences.getInstance();
    final defaultFlow = day <= _profile.periodDurationDays ? 'medium' : 'none';

    setState(() {
      _flow = prefs.getString('cycle_flow_day_$day') ?? defaultFlow;
      _energyScore = prefs.getInt('cycle_energy_day_$day') ?? (prefs.getInt('cycle_symptom_energy') ?? 4);
      _crampLevel = prefs.getInt('cycle_cramps_day_$day') ?? (prefs.getInt('cycle_symptom_cramps') ?? (day <= 3 ? 1 : 0));
      _mood = prefs.getString('cycle_mood_day_$day') ?? (prefs.getString('cycle_symptom_mood') ?? 'Спокойствие');
      _selectedSymptoms.clear();
      final symptomsList = prefs.getStringList('cycle_symptoms_day_$day');
      if (symptomsList != null) {
        _selectedSymptoms.addAll(symptomsList);
      } else if (day <= 3) {
        _selectedSymptoms.add('Спазмы');
      }
      _noteController.text = prefs.getString('cycle_note_day_$day') ?? '';
    });
  }

  Future<void> _saveCurrentDayLog() async {
    final prefs = await SharedPreferences.getInstance();
    final day = _selectedDay;

    await prefs.setString('cycle_mark_day_$day', 'true');
    await prefs.setString('cycle_flow_day_$day', _flow);
    await prefs.setInt('cycle_energy_day_$day', _energyScore);
    await prefs.setInt('cycle_cramps_day_$day', _crampLevel);
    await prefs.setString('cycle_mood_day_$day', _mood);
    await prefs.setStringList('cycle_symptoms_day_$day', _selectedSymptoms.toList());
    await prefs.setString('cycle_note_day_$day', _noteController.text.trim());

    // Legacy keys
    await prefs.setInt('cycle_symptom_energy', _energyScore);
    await prefs.setInt('cycle_symptom_cramps', _crampLevel);
    await prefs.setString('cycle_symptom_mood', _mood);

    // Автоматическая передача в биоритм партнёра
    await PartnerCycleRepository.syncFromFemaleProfile(
      _profile,
      currentCycleDay: day,
      energyScore: _energyScore,
      mood: _mood,
      flow: _flow,
      symptoms: _selectedSymptoms.toList(),
      note: _noteController.text.trim(),
      skinTempDeviation: _telemetry.skinTempDeviation,
    );

    setState(() {
      _daysWithMarks.add(day);
    });

    CircaHaptics.success();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            'Отметки за день $day сохранены${_partnerLinked ? ' и переданы партнёру ($_partnerName)' : ''}',
            style: TextStyle(color: AppColors.fg),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _markPeriodStartedToday() async {
    CircaHaptics.heavyAlert();
    final now = DateTime.now();
    final updated = _profile.copyWith(
      lastPeriodStartDate: now,
      cycleDay: 1,
    );
    await UserProfileRepository.saveProfile(updated);

    setState(() {
      _profile = updated;
      _selectedDay = 1;
      _flow = 'medium';
    });

    await _saveCurrentDayLog();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surface,
          content: Text(
            '🩸 Новый цикл начат. День 1 зафиксирован сенсорами СААТ-1',
            style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
  }

  void _openPartnerSyncDialog(AppLanguage language) {
    final nameCtrl = TextEditingController(text: _partnerName);
    bool linked = _partnerLinked;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.stage,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: AppColors.lineStrong, width: 1.2)),
              ),
              padding: EdgeInsets.only(
                top: 14,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: AppColors.lineStrong, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.rose.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.favorite, color: AppColors.rose, size: 18),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Синхронизация с партнёром',
                            style: TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: AppColors.muted, size: 20),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    const Text(
                      'Партнёр сможет видеть на своём главном экране карточку вашего биоритма, текущую фазу и подсказки, как проявить заботу и поддержку.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ВАШ ИНВАЙТ-КОД ДЛЯ ПАРТНЁРА',
                            style: TextStyle(color: AppColors.muted, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                          ),
                          SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _partnerInviteCode,
                                style: const TextStyle(
                                  color: AppColors.amber,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _partnerInviteCode));
                                  CircaHaptics.success();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Код $_partnerInviteCode скопирован'),
                                      backgroundColor: AppColors.surface,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy, size: 12),
                                label: const Text('Копировать', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.raised,
                                  foregroundColor: AppColors.fg,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: AppColors.fg, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Имя партнёра',
                        labelStyle: TextStyle(color: AppColors.muted, fontSize: 12),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.amber)),
                        prefixIcon: Icon(Icons.person_outline, color: AppColors.muted, size: 18),
                      ),
                    ),
                    SizedBox(height: 14),
                    SwitchListTile(
                      title: Text('Разрешить партнёру видеть цикл', style: TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: Text('Отображать карточку биоритма на его главном экране', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                      value: linked,
                      activeThumbColor: AppColors.rose,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setSheetState(() => linked = val);
                      },
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final partnerName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Алихан';
                        if (linked) {
                          await PartnerCycleRepository.linkPartner(
                            partnerCode: _partnerInviteCode,
                            partnerName: partnerName,
                            cycleDay: _selectedDay,
                            cycleLength: _profile.cycleLengthDays,
                          );
                          await PartnerCycleRepository.syncFromFemaleProfile(
                            _profile,
                            currentCycleDay: _selectedDay,
                            energyScore: _energyScore,
                            mood: _mood,
                            flow: _flow,
                            symptoms: _selectedSymptoms.toList(),
                            note: _noteController.text.trim(),
                            skinTempDeviation: _telemetry.skinTempDeviation,
                          );
                        } else {
                          await PartnerCycleRepository.unlinkPartner();
                        }
                        setState(() {
                          _partnerLinked = linked;
                          _partnerName = partnerName;
                        });
                        CircaHaptics.success();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.surface,
                              content: Text(linked
                                  ? 'Связь с партнёром ($partnerName) активирована'
                                  : 'Связь с партнёром отключена'),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.rose,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('СОХРАНИТЬ НАСТРОЙКИ СВЯЗИ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
        return const Color(0xFFA685B8);
    }
  }

  String _phaseTitle(HormonalCyclePhase phase, AppLanguage language) {
    switch (phase) {
      case HormonalCyclePhase.menstrual:
        return AppStrings.tr('cycle_phase_menstrual', language);
      case HormonalCyclePhase.follicular:
        return AppStrings.tr('cycle_phase_follicular', language);
      case HormonalCyclePhase.ovulatory:
        return AppStrings.tr('cycle_phase_ovulatory', language);
      case HormonalCyclePhase.luteal:
        return AppStrings.tr('cycle_phase_luteal', language);
    }
  }

  void _openSettingsDialog(AppLanguage language) {
    int length = _profile.cycleLengthDays;
    int periodLen = _profile.periodDurationDays;
    DateTime? startDate = _profile.lastPeriodStartDate ?? DateTime.now().subtract(const Duration(days: 14));

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.settings, color: AppColors.amber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    AppStrings.tr('cycle_edit_settings', language),
                    style: TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${language == AppLanguage.kyrgyz ? 'Циклдин узактыгы' : 'Длина цикла'}: $length дней',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  Slider(
                    value: length.toDouble(),
                    min: 21,
                    max: 35,
                    divisions: 14,
                    activeColor: AppColors.amber,
                    inactiveColor: AppColors.raised,
                    onChanged: (v) => setDialogState(() => length = v.round()),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '${language == AppLanguage.kyrgyz ? 'Этек кирдин узактыгы' : 'Длительность менструации'}: $periodLen дней',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  Slider(
                    value: periodLen.toDouble(),
                    min: 3,
                    max: 8,
                    divisions: 5,
                    activeColor: AppColors.rose,
                    inactiveColor: AppColors.raised,
                    onChanged: (v) => setDialogState(() => periodLen = v.round()),
                  ),
                  SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 60)),
                        lastDate: DateTime.now(),
                        builder: (ctx, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.amber,
                                surface: AppColors.surface,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() => startDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.raised,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            language == AppLanguage.kyrgyz ? 'Акыркы башталышы' : 'Начало последних месячных',
                            style: TextStyle(color: AppColors.fg, fontSize: 12),
                          ),
                          Text(
                            startDate != null ? '${startDate!.day}.${startDate!.month}.${startDate!.year}' : 'Выбрать',
                            style: const TextStyle(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('ОТМЕНА', style: TextStyle(color: AppColors.muted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogCtx).pop();
                    final updated = _profile.copyWith(
                      cycleLengthDays: length,
                      periodDurationDays: periodLen,
                      lastPeriodStartDate: startDate,
                    );
                    await UserProfileRepository.saveProfile(updated);
                    setState(() {
                      _profile = updated;
                      _selectedDay = MenstrualCycleEngine.calculateCurrentCycleDay(startDate, cycleLength: length);
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surface,
                          content: Text(
                            AppStrings.tr('cycle_settings_saved', language),
                            style: TextStyle(color: AppColors.fg),
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.stage,
                    elevation: 0,
                  ),
                  child: const Text('СОХРАНИТЬ', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        final analysis = MenstrualCycleEngine.analyze(
          telemetry: _telemetry,
          profile: _profile,
          language: language,
        );

        final selectedPhase = MenstrualCycleEngine.determinePhase(
          _selectedDay,
          cycleLength: _profile.cycleLengthDays,
          periodDuration: _profile.periodDurationDays,
        );
        final pColor = _phaseColor(selectedPhase);

        return Scaffold(
          backgroundColor: AppColors.stage,
          appBar: AppBar(
            backgroundColor: AppColors.stage,
            elevation: 0,
            leading: Navigator.of(context).canPop()
                ? IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: AppColors.fg, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.tr('cycle_screen_title', language),
                  style: TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  AppStrings.tr('cycle_screen_subtitle', language),
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _partnerLinked ? Icons.favorite : Icons.favorite_border,
                  color: _partnerLinked ? AppColors.rose : AppColors.muted,
                  size: 20,
                ),
                tooltip: 'Синхронизация с партнёром',
                onPressed: () => _openPartnerSyncDialog(language),
              ),
              IconButton(
                icon: const Icon(Icons.tune, color: AppColors.amber, size: 20),
                tooltip: AppStrings.tr('cycle_edit_settings', language),
                onPressed: () => _openSettingsDialog(language),
              ),
            ],
          ),
          body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Интерактивный 28-дневный диск / селектор дней
                  _buildDayOrbitSelector(analysis.currentDay, pColor, language),
                  SizedBox(height: 12),

                  // Кнопка быстрого начала нового цикла
                  _buildFastPeriodStartButton(language),
                  SizedBox(height: 14),

                  // Карточка связи и синхронизации с партнёром
                  _buildPartnerSyncCard(language),
                  SizedBox(height: 16),

                  // 2. Карточка текущей фазы и статуса сенсоров СААТ-1
                  _buildPhaseOverviewCard(selectedPhase, pColor, analysis, language),
                  SizedBox(height: 16),

                  // 3. Ночная кривая термометрии кожи СААТ-1
                  _buildThermalGraphCard(analysis, pColor, language),
                  SizedBox(height: 16),

                  // 4. Персональные директивы (4 столпа биоритма)
                  _buildPillarsDirectivesCard(analysis, pColor, language),
                  SizedBox(height: 16),

                  // 5. Дневник самочувствия и симптомов
                  _buildSymptomsLogger(language),
                  SizedBox(height: 24),
                ],
              ),
            ),
        );
      },
    );
  }

  Widget _buildFastPeriodStartButton(AppLanguage language) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.rose.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.35)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _markPeriodStartedToday,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.water_drop, color: AppColors.rose, size: 18),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language == AppLanguage.kyrgyz
                            ? 'Бүгүн этек кир башталды'
                            : 'Месячные начались сегодня',
                        style: const TextStyle(
                          color: AppColors.rose,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        language == AppLanguage.kyrgyz
                            ? '1-күндү белгилөө жана циклди башынан эсептөө'
                            : 'Начать новый цикл (День 1) и откалибровать прогноз',
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: AppColors.rose, size: 13),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerSyncCard(AppLanguage language) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _partnerLinked ? Icons.favorite : Icons.favorite_border,
                  color: AppColors.rose,
                  size: 15,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  language == AppLanguage.kyrgyz ? 'ӨНӨКТӨШ МЕНЕН СИНХРОН' : 'СИНХРОНИЗАЦИЯ С ПАРТНЁРОМ',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _partnerLinked
                      ? AppColors.sage.withValues(alpha: 0.15)
                      : AppColors.raised,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _partnerLinked ? 'АКТИВНА' : 'НЕ ПОДКЛЮЧЁН',
                  style: TextStyle(
                    color: _partnerLinked ? AppColors.sage : AppColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            _partnerLinked
                ? 'Партнёр ($_partnerName) видит фазу вашего цикла на своём главном экране и получает подсказки, как вас поддержать.'
                : 'Поделитесь кодом с партнёром, чтобы он видел текущую фазу и заботился о вас в соответствии с вашим биоритмом.',
            style: TextStyle(color: AppColors.fg, fontSize: 12, height: 1.35),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _partnerInviteCode,
                        style: const TextStyle(
                          color: AppColors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _partnerInviteCode));
                          CircaHaptics.selectionClick();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Код $_partnerInviteCode скопирован'),
                              backgroundColor: AppColors.surface,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Icon(Icons.copy, size: 14, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _openPartnerSyncDialog(language),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.raised,
                  foregroundColor: AppColors.fg,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('НАСТРОИТЬ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayOrbitSelector(int todayDay, Color activeColor, AppLanguage language) {
    return GlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${language == AppLanguage.kyrgyz ? 'БИОРИТМДИН КҮНДӨРҮ' : 'ДНИ БИОРИТМА'} ($_selectedDay / ${_profile.cycleLengthDays})',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              if (_selectedDay == todayDay)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    language == AppLanguage.kyrgyz ? 'Бүгүн' : 'Сегодня',
                    style: const TextStyle(color: AppColors.sage, fontSize: 9.5, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _profile.cycleLengthDays,
              separatorBuilder: (ctx, idx) => SizedBox(width: 8),
              itemBuilder: (context, index) {
                final day = index + 1;
                final isSelected = day == _selectedDay;
                final isToday = day == todayDay;
                final hasMarks = _daysWithMarks.contains(day);
                final phase = MenstrualCycleEngine.determinePhase(
                  day,
                  cycleLength: _profile.cycleLengthDays,
                  periodDuration: _profile.periodDurationDays,
                );
                final dotColor = _phaseColor(phase);

                return GestureDetector(
                  onTap: () async {
                    CircaHaptics.selectionClick();
                    setState(() => _selectedDay = day);
                    await _loadDayLog(day);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 42,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.raised : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? dotColor : (isToday ? AppColors.lineStrong : AppColors.line),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            color: isSelected ? AppColors.fg : AppColors.muted,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (hasMarks) ...[
                              SizedBox(width: 2),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: AppColors.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseOverviewCard(
    HormonalCyclePhase phase,
    Color pColor,
    CycleAnalysisResult analysis,
    AppLanguage language,
  ) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: pColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _phaseTitle(phase, language),
                  style: TextStyle(color: pColor, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              const Spacer(),
              Icon(Icons.watch_outlined, color: AppColors.muted, size: 16),
              SizedBox(width: 4),
              const Text(
                'СААТ-1 СИНХРОН',
                style: TextStyle(color: AppColors.muted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.0),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            analysis.thermalAdviceText,
            style: TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600, height: 1.35),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.raised, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STRAIN БЮДЖЕТ', style: TextStyle(color: AppColors.faint, fontSize: 9, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text(
                        '${analysis.targetStrainMin.toStringAsFixed(1)}–${analysis.targetStrainMax.toStringAsFixed(1)}',
                        style: TextStyle(color: pColor, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.raised, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ТЕРМОСЕНСОР', style: TextStyle(color: AppColors.faint, fontSize: 9, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text(
                        '${analysis.skinTempDeviation >= 0 ? '+' : ''}${analysis.skinTempDeviation.toStringAsFixed(2)}°C',
                        style: const TextStyle(color: AppColors.amber, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThermalGraphCard(CycleAnalysisResult analysis, Color activeColor, AppLanguage language) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.tr('cycle_thermal_card', language),
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.sage, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'BLE 5.3 CALIBRATED',
                      style: TextStyle(color: AppColors.sage, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            AppStrings.tr('cycle_thermal_desc', language),
            style: TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.3),
          ),
          SizedBox(height: 16),

          // Визуализация двухфазной температурной кривой (Custom Canvas)
          SizedBox(
            height: 110,
            child: CustomPaint(
              size: const Size(double.infinity, 110),
              painter: _ThermalCurvePainter(
                currentDay: _selectedDay,
                totalDays: _profile.cycleLengthDays,
                activeColor: activeColor,
              ),
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                language == AppLanguage.kyrgyz ? 'Фолликулярдык (Муздак)' : 'Фолликулярная (-0.3°C)',
                style: const TextStyle(color: AppColors.sage, fontSize: 10, fontWeight: FontWeight.w600),
              ),
              Text(
                language == AppLanguage.kyrgyz ? 'Овуляция (Секирик)' : 'Овуляция (+0.2°C)',
                style: const TextStyle(color: AppColors.amber, fontSize: 10, fontWeight: FontWeight.w600),
              ),
              Text(
                language == AppLanguage.kyrgyz ? 'Лютеиндик (+0.45°C)' : 'Лютеиновая (+0.45°C)',
                style: const TextStyle(color: Color(0xFFA685B8), fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillarsDirectivesCard(CycleAnalysisResult analysis, Color pColor, AppLanguage language) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '4 СТОЛПА БИОРИТМА (СААТ-1 ДИРЕКТИВЫ)',
            style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5),
          ),
          SizedBox(height: 14),

          // 1. Тренировки
          _buildDirectiveRow(
            icon: Icons.fitness_center,
            color: pColor,
            title: AppStrings.tr('cycle_directive_training', language),
            text: analysis.trainingDirective,
          ),
          const Divider(color: AppColors.line, height: 20),

          // 2. Питание
          _buildDirectiveRow(
            icon: Icons.restaurant,
            color: AppColors.amber,
            title: AppStrings.tr('cycle_directive_nutrition', language),
            text: analysis.nutritionDirective,
          ),
          const Divider(color: AppColors.line, height: 20),

          // 3. Сон
          _buildDirectiveRow(
            icon: Icons.bedtime,
            color: AppColors.sage,
            title: AppStrings.tr('cycle_directive_sleep', language),
            text: analysis.sleepDirective,
          ),
          const Divider(color: AppColors.line, height: 20),

          // 4. Барыс
          _buildDirectiveRow(
            icon: Icons.auto_awesome,
            color: AppColors.amber,
            title: AppStrings.tr('cycle_directive_barys', language),
            text: analysis.barysQuote,
          ),
        ],
      ),
    );
  }

  Widget _buildDirectiveRow({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 3),
              Text(
                text,
                style: TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlowChip(String flowKey, String label, Color color) {
    final isSel = _flow == flowKey;
    return GestureDetector(
      onTap: () {
        CircaHaptics.selectionClick();
        setState(() => _flow = flowKey);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? color.withValues(alpha: 0.22) : AppColors.raised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSel ? color : AppColors.line, width: isSel ? 1.5 : 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (flowKey != 'none') ...[
              Icon(Icons.water_drop, size: 12, color: isSel ? color : AppColors.muted),
              SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSel ? color : AppColors.muted,
                fontSize: 11,
                fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomsLogger(AppLanguage language) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppStrings.tr('cycle_symptoms_title', language)} (ДЕНЬ $_selectedDay)',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              if (_daysWithMarks.contains(_selectedDay))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 10, color: AppColors.amber),
                      SizedBox(width: 3),
                      Text(
                        'ОТМЕЧЕНО',
                        style: TextStyle(color: AppColors.amber, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 14),

          // 1. Выделения / менструация
          const Text(
            'ВЫДЕЛЕНИЯ / МЕНСТРУАЦИЯ',
            style: TextStyle(color: AppColors.faint, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
          SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFlowChip('none', 'Нет', AppColors.muted),
                SizedBox(width: 6),
                _buildFlowChip('spotting', 'Мажущие', const Color(0xFFD67B80)),
                SizedBox(width: 6),
                _buildFlowChip('light', 'Скудные', AppColors.rose),
                SizedBox(width: 6),
                _buildFlowChip('medium', 'Умеренные', AppColors.rose),
                SizedBox(width: 6),
                _buildFlowChip('heavy', 'Обильные', const Color(0xFFE02E49)),
              ],
            ),
          ),
          SizedBox(height: 16),

          // 2. Энергия
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.tr('cycle_symptom_energy', language),
                    style: TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _energyScore >= 4 ? 'Высокий тонус' : (_energyScore == 3 ? 'Базовый уровень' : 'Сниженная энергия'),
                    style: TextStyle(color: AppColors.muted, fontSize: 10.5),
                  ),
                ],
              ),
              Row(
                children: List.generate(5, (index) {
                  final score = index + 1;
                  final isFilled = score <= _energyScore;
                  return GestureDetector(
                    onTap: () {
                      CircaHaptics.selectionClick();
                      setState(() => _energyScore = score);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.bolt,
                        size: 24,
                        color: isFilled ? AppColors.amber : AppColors.faint,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          SizedBox(height: 16),

          // 3. Спазмы
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.tr('cycle_symptom_cramps', language),
                style: TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Row(
                children: ['Нет', 'Слабые', 'Умерен.', 'Сильные'].asMap().entries.map((e) {
                  final idx = e.key;
                  final label = e.value;
                  final isSel = idx == _crampLevel;
                  return GestureDetector(
                    onTap: () {
                      CircaHaptics.selectionClick();
                      setState(() => _crampLevel = idx);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.rose.withValues(alpha: 0.2) : AppColors.raised,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSel ? AppColors.rose : AppColors.line),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSel ? AppColors.rose : AppColors.muted,
                          fontSize: 10.5,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          SizedBox(height: 16),

          // 4. Настроение
          Text(
            AppStrings.tr('cycle_symptom_mood', language),
            style: TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              'Спокойствие',
              'Драйв',
              'Дзен',
              'Усталость',
              'Раздражение',
              'Нежность',
            ].map((m) {
              final isSel = _mood == m;
              return GestureDetector(
                onTap: () {
                  CircaHaptics.selectionClick();
                  setState(() => _mood = m);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? AppColors.sage.withValues(alpha: 0.2) : AppColors.raised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSel ? AppColors.sage : AppColors.line),
                  ),
                  child: Text(
                    m,
                    style: TextStyle(
                      color: isSel ? AppColors.sage : AppColors.muted,
                      fontSize: 11.5,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 16),

          // 5. Симптомы и ощущения
          const Text(
            'СИМПТОМЫ И ОЩУЩЕНИЯ ТЕЛА',
            style: TextStyle(color: AppColors.faint, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              'Спазмы',
              'Головная боль',
              'Вздутие',
              'Сонливость',
              'Тяга к сладкому',
              'Чувствительность груди',
              'Высокий тонус',
              'Нужен отдых',
            ].map((sym) {
              final isSel = _selectedSymptoms.contains(sym);
              return FilterChip(
                label: Text(sym),
                labelStyle: TextStyle(
                  color: isSel ? AppColors.amber : AppColors.muted,
                  fontSize: 11.5,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                ),
                selected: isSel,
                selectedColor: AppColors.amber.withValues(alpha: 0.18),
                backgroundColor: AppColors.raised,
                side: BorderSide(color: isSel ? AppColors.amber : AppColors.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                showCheckmark: false,
                onSelected: (val) {
                  CircaHaptics.selectionClick();
                  setState(() {
                    if (val) {
                      _selectedSymptoms.add(sym);
                    } else {
                      _selectedSymptoms.remove(sym);
                    }
                  });
                },
              );
            }).toList(),
          ),
          SizedBox(height: 16),

          // 6. Личная заметка
          TextField(
            controller: _noteController,
            maxLines: 2,
            style: TextStyle(color: AppColors.fg, fontSize: 12.5),
            decoration: InputDecoration(
              hintText: 'Личная заметка о самочувствии...',
              hintStyle: TextStyle(color: AppColors.faint, fontSize: 12),
              filled: true,
              fillColor: AppColors.raised,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.amber)),
            ),
          ),
          SizedBox(height: 16),

          // 7. Кнопка сохранения отметок
          ElevatedButton.icon(
            onPressed: _saveCurrentDayLog,
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: Text(
              'СОХРАНИТЬ ОТМЕТКИ ДНЯ ($_selectedDay)',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.stage,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Художественный отрисовщик двухфазной кривой ночной температуры СААТ-1
class _ThermalCurvePainter extends CustomPainter {
  final int currentDay;
  final int totalDays;
  final Color activeColor;

  _ThermalCurvePainter({
    required this.currentDay,
    required this.totalDays,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Базовая линия 0.0°C (середина графика)
    final zeroY = h * 0.55;
    final baseLinePaint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, zeroY), Offset(w, zeroY), baseLinePaint);

    final path = Path();
    final fillPath = Path();

    final points = <Offset>[];
    for (int d = 1; d <= totalDays; d++) {
      final x = ((d - 1) / (totalDays - 1)) * w;
      final delta = MenstrualCycleEngine.expectedThermalDelta(d, cycleLength: totalDays);
      // Масштаб: +0.6°C это верх (y ~ 0.1*h), -0.4°C это низ (y ~ 0.9*h)
      final y = zeroY - (delta / 0.6) * (h * 0.4);
      points.add(Offset(x, y));
    }

    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      fillPath.moveTo(points.first.dx, h);
      fillPath.lineTo(points.first.dx, points.first.dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
        fillPath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }

      fillPath.lineTo(points.last.dx, h);
      fillPath.close();

      // Заливка под графиком
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            activeColor.withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h))
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      // Контур линии
      final linePaint = Paint()
        ..color = activeColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, linePaint);

      // Точка текущего дня
      final currentIdx = (currentDay - 1).clamp(0, points.length - 1);
      final curPoint = points[currentIdx];

      // Свечение текущего дня
      final glowPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(curPoint, 8, glowPaint);

      final dotPaint = Paint()..color = AppColors.fg;
      canvas.drawCircle(curPoint, 4.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ThermalCurvePainter oldDelegate) {
    return oldDelegate.currentDay != currentDay || oldDelegate.totalDays != totalDays;
  }
}
