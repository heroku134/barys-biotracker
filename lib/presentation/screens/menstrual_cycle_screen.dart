import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/intelligence/menstrual_cycle_engine.dart';
import '../../domain/models/telemetry.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/circa_film_grain.dart';
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
  int _energyScore = 4; // 1..5
  int _crampLevel = 1; // 0..3
  String _mood = 'Спокойное';

  @override
  void initState() {
    super.initState();
    _telemetry = widget.bleBridge.currentTelemetry;
    _loadProfileAndSymptoms();

    widget.bleBridge.telemetryStream.listen((data) {
      if (mounted) setState(() => _telemetry = data);
    });
  }

  Future<void> _loadProfileAndSymptoms() async {
    final p = await UserProfileRepository.loadProfile();
    final prefs = await SharedPreferences.getInstance();
    final currentDay = MenstrualCycleEngine.calculateCurrentCycleDay(
      p.lastPeriodStartDate,
      cycleLength: p.cycleLengthDays > 0 ? p.cycleLengthDays : 28,
    );

    if (mounted) {
      setState(() {
        _profile = p;
        _selectedDay = currentDay;
        _energyScore = prefs.getInt('cycle_symptom_energy') ?? 4;
        _crampLevel = prefs.getInt('cycle_symptom_cramps') ?? 1;
        _mood = prefs.getString('cycle_symptom_mood') ?? 'Спокойное';
      });
    }
  }

  Future<void> _saveSymptom(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
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
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.tr('cycle_edit_settings', language),
                    style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${language == AppLanguage.kyrgyz ? 'Циклдин узактыгы' : 'Длина цикла'}: $length дней',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
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
                  const SizedBox(height: 10),
                  Text(
                    '${language == AppLanguage.kyrgyz ? 'Этек кирдин узактыгы' : 'Длительность менструации'}: $periodLen дней',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
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
                  const SizedBox(height: 10),
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
                            style: const TextStyle(color: AppColors.fg, fontSize: 12),
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
                  child: const Text('ОТМЕНА', style: TextStyle(color: AppColors.muted)),
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
                            style: const TextStyle(color: AppColors.fg),
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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: AppColors.fg, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.tr('cycle_screen_title', language),
                  style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  AppStrings.tr('cycle_screen_subtitle', language),
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune, color: AppColors.amber, size: 20),
                tooltip: AppStrings.tr('cycle_edit_settings', language),
                onPressed: () => _openSettingsDialog(language),
              ),
            ],
          ),
          body: CircaFilmGrainBackground(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Интерактивный 28-дневный диск / селектор дней
                  _buildDayOrbitSelector(analysis.currentDay, pColor, language),
                  const SizedBox(height: 16),

                  // 2. Карточка текущей фазы и статуса сенсоров СААТ-1
                  _buildPhaseOverviewCard(selectedPhase, pColor, analysis, language),
                  const SizedBox(height: 16),

                  // 3. Ночная кривая термометрии кожи СААТ-1
                  _buildThermalGraphCard(analysis, pColor, language),
                  const SizedBox(height: 16),

                  // 4. Персональные директивы (4 столпа биоритма)
                  _buildPillarsDirectivesCard(analysis, pColor, language),
                  const SizedBox(height: 16),

                  // 5. Дневник самочувствия и симптомов
                  _buildSymptomsLogger(language),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
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
                style: const TextStyle(
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
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _profile.cycleLengthDays,
              separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final day = index + 1;
                final isSelected = day == _selectedDay;
                final isToday = day == todayDay;
                final phase = MenstrualCycleEngine.determinePhase(
                  day,
                  cycleLength: _profile.cycleLengthDays,
                  periodDuration: _profile.periodDurationDays,
                );
                final dotColor = _phaseColor(phase);

                return GestureDetector(
                  onTap: () {
                    CircaHaptics.selectionClick();
                    setState(() => _selectedDay = day);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
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
                        const SizedBox(height: 3),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
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
              const Icon(Icons.watch_outlined, color: AppColors.muted, size: 16),
              const SizedBox(width: 4),
              const Text(
                'СААТ-1 СИНХРОН',
                style: TextStyle(color: AppColors.muted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            analysis.thermalAdviceText,
            style: const TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.raised, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('STRAIN БЮДЖЕТ', style: TextStyle(color: AppColors.faint, fontSize: 9, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '${analysis.targetStrainMin.toStringAsFixed(1)}–${analysis.targetStrainMax.toStringAsFixed(1)}',
                        style: TextStyle(color: pColor, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.raised, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ТЕРМОСЕНСОР', style: TextStyle(color: AppColors.faint, fontSize: 9, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
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
                style: const TextStyle(
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
                child: const Row(
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
          const SizedBox(height: 6),
          Text(
            AppStrings.tr('cycle_thermal_desc', language),
            style: const TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.3),
          ),
          const SizedBox(height: 16),

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
          const SizedBox(height: 8),
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
          const SizedBox(height: 14),

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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSymptomsLogger(AppLanguage language) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.tr('cycle_symptoms_title', language),
            style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5),
          ),
          const SizedBox(height: 14),

          // Энергия
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppStrings.tr('cycle_symptom_energy', language), style: const TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600)),
              Row(
                children: List.generate(5, (index) {
                  final score = index + 1;
                  final isFilled = score <= _energyScore;
                  return GestureDetector(
                    onTap: () {
                      CircaHaptics.selectionClick();
                      setState(() => _energyScore = score);
                      _saveSymptom('cycle_symptom_energy', score);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(
                        Icons.bolt,
                        size: 22,
                        color: isFilled ? AppColors.amber : AppColors.faint,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Спазмы
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppStrings.tr('cycle_symptom_cramps', language), style: const TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600)),
              Row(
                children: ['Нет', 'Слабые', 'Умерен.', 'Сильные'].asMap().entries.map((e) {
                  final idx = e.key;
                  final label = e.value;
                  final isSel = idx == _crampLevel;
                  return GestureDetector(
                    onTap: () {
                      CircaHaptics.selectionClick();
                      setState(() => _crampLevel = idx);
                      _saveSymptom('cycle_symptom_cramps', idx);
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
                          fontSize: 10,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Настроение
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppStrings.tr('cycle_symptom_mood', language), style: const TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600)),
              Row(
                children: ['✨ Спокойствие', '🔥 Драйв', '🧘 Дзен', '🌧️ Усталость'].map((m) {
                  final isSel = _mood == m;
                  return GestureDetector(
                    onTap: () {
                      CircaHaptics.selectionClick();
                      setState(() => _mood = m);
                      _saveSymptom('cycle_symptom_mood', m);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.sage.withValues(alpha: 0.2) : AppColors.raised,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSel ? AppColors.sage : AppColors.line),
                      ),
                      child: Text(
                        m.split(' ')[0], // Эмодзи
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
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
