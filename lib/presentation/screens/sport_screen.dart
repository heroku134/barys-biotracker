import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/circa_haptics.dart';
import '../../data/services/paired_pulse.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/workout_repository.dart';
import '../../data/storage/local_day_strain.dart';
import '../../domain/intelligence/readiness_engine.dart';
import 'workout_summary_screen.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/models/workout_session.dart';
import '../widgets/circa_edge_fade.dart';
import '../widgets/circa_pulsing_logo.dart';
import '../widgets/glass_card.dart';
import '../../data/services/live_activity_service.dart';
import '../../data/services/system_notification_service.dart';

class SportScreen extends StatefulWidget {
  final UteBleBridge bleBridge;

  const SportScreen({super.key, required this.bleBridge});

  @override
  State<SportScreen> createState() => _SportScreenState();
}

class _SportScreenState extends State<SportScreen> {
  SportType _selectedSport = SportType.runOutdoor;
  bool _isAutoDetectImu = true;
  List<CompletedWorkout> _history = [];

  // Состояние активной тренировки
  bool _isWorkoutActive = false;
  bool _isWorkoutPaused = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  int _peakHr = 0;
  double _distanceKm = 0.0;
  int _caloriesBurned = 0;
  StreamSubscription? _bleSub;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _bleSub = widget.bleBridge.telemetryStream.listen((data) {
      if (!mounted || !_isWorkoutActive || _isWorkoutPaused) return;
      setState(() {
        if (data.heartRate > _peakHr) _peakHr = data.heartRate;
      });
    });
  }

  Future<void> _loadHistory() async {
    final list = await WorkoutRepository.loadWorkouts();
    if (mounted) setState(() => _history = list);
  }

  int get _weekMinutes {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final from = DateTime(start.year, start.month, start.day);
    return _history
        .where((w) => !w.startedAt.isBefore(from))
        .fold<int>(0, (s, w) => s + (w.durationSeconds ~/ 60));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bleSub?.cancel();
    super.dispose();
  }

  void _startWorkout() {
    PairedPulse.play(widget.bleBridge, kind: PairedPulseKind.start);
    final initialHr = widget.bleBridge.currentTelemetry.heartRate > 0 ? widget.bleBridge.currentTelemetry.heartRate : 72;
    setState(() {
      _isWorkoutActive = true;
      _isWorkoutPaused = false;
      _elapsedSeconds = 0;
      _peakHr = initialHr;
      _distanceKm = 0.0;
      _caloriesBurned = 0;
    });

    // Запуск iOS Live Activities & Dynamic Island
    LiveActivityService.startWorkoutActivity(
      workoutName: _selectedSport.title,
      workoutType: _selectedSport.id,
      initialHeartRate: initialHr,
      heartRateZone: 2,
      currentStrain: 0.0,
      activeCalories: 0,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isWorkoutPaused) {
        setState(() {
          _elapsedSeconds++;
          final currentBpm = widget.bleBridge.currentTelemetry.heartRate;
          if (currentBpm > _peakHr) _peakHr = currentBpm;

          // Расчет сожженных калорий и дистанции
          if (_elapsedSeconds % 4 == 0) {
            _caloriesBurned += (_selectedSport == SportType.hiit ? 2 : 1);
          }
          if (_selectedSport.hasDistance && _elapsedSeconds % 6 == 0) {
            _distanceKm += 0.02;
          }

          // Обновление Dynamic Island каждые 2 секунды
          if (_elapsedSeconds % 2 == 0) {
            final double liveStrain = StrainEngine.calculateWorkoutStrain(
              durationMinutes: _elapsedSeconds / 60.0,
              avgHeartRate: currentBpm > 0 ? currentBpm : 120,
              sportType: _selectedSport.id,
            );
            final zone = (currentBpm < 100) ? 1 : (currentBpm < 125) ? 2 : (currentBpm < 150) ? 3 : (currentBpm < 170) ? 4 : 5;
            LiveActivityService.updateWorkoutActivity(
              heartRate: currentBpm > 0 ? currentBpm : 120,
              heartRateZone: zone,
              currentStrain: liveStrain,
              activeCalories: _caloriesBurned,
              workoutType: _selectedSport.title,
            );
          }
        });
      }
    });
  }

  void _togglePause() {
    HapticFeedback.mediumImpact();
    setState(() => _isWorkoutPaused = !_isWorkoutPaused);
  }

  Future<void> _stopWorkout() async {
    _timer?.cancel();
    PairedPulse.play(widget.bleBridge, kind: PairedPulseKind.finish);

    // Завершение iOS Live Activities
    await LiveActivityService.endWorkoutActivity();

    final duration = _elapsedSeconds;
    final avgHr = widget.bleBridge.currentTelemetry.heartRate;
    final maxHr = _peakHr > 0 ? _peakHr : avgHr;
    final cals = _caloriesBurned > 0 ? _caloriesBurned : (duration ~/ 10);

    // Расчет заработанного Strain
    final double calculatedStrain = StrainEngine.calculateWorkoutStrain(
      durationMinutes: duration / 60.0,
      avgHeartRate: avgHr,
      sportType: _selectedSport.id,
    );

    // Начисление опыта Барысу
    final xp = AvatarManager.recordWorkout(calculatedStrain);

    final completed = CompletedWorkout(
      id: 'w_${DateTime.now().millisecondsSinceEpoch}',
      sport: _selectedSport,
      startedAt: DateTime.now().subtract(Duration(seconds: duration)),
      durationSeconds: duration,
      calories: cals,
      distanceKm: double.parse(_distanceKm.toStringAsFixed(2)),
      avgHr: avgHr,
      maxHr: maxHr,
      strain: calculatedStrain,
      xpEarned: xp,
    );

    final dayBefore = widget.bleBridge.currentTelemetry.currentDayStrain > 0
        ? widget.bleBridge.currentTelemetry.currentDayStrain
        : 0.0;
    final zone = ReadinessEngine.calculate(widget.bleBridge.currentTelemetry).zone;

    LocalDayStrain.add(calculatedStrain);
    final dayAfter = dayBefore + calculatedStrain;
    final rec = ReadinessEngine.calculate(widget.bleBridge.currentTelemetry);
    SystemNotificationService.notifyWorkoutEnd(
      sessionStrain: calculatedStrain,
      dayStrain: dayAfter,
      targetMax: StrainEngine.evaluate(currentStrain: dayAfter, recoveryZone: rec.zone).targetStrainMax,
    );

    await WorkoutRepository.saveWorkout(completed);
    await _loadHistory();

    if (!mounted) return;
    setState(() {
      _isWorkoutActive = false;
      _isWorkoutPaused = false;
      _elapsedSeconds = 0;
    });

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          workout: completed,
          dayStrainBefore: dayBefore,
          recoveryZone: zone,
        ),
      ),
    );
    return;
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.bleBridge.currentTelemetry;
    final currentBpm = telemetry.heartRate;

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        final palette = KalkanColors.of(context);
        return Scaffold(
          backgroundColor: palette.bg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leadingWidth: 52,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.35), width: 1.0),
                  ),
                  child: const CircaPulsingLogo(size: 26, animate: false),
                ),
              ),
            ),
            titleSpacing: 6,
            title: Text(
              AppStrings.tr('sport_title', language),
              style: TextStyle(
                color: palette.fg,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.raised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt, color: AppColors.amber, size: 14),
                SizedBox(width: 4),
                Text(
                  '${telemetry.currentDayStrain.toStringAsFixed(1)} / 21',
                  style: TextStyle(color: palette.fg, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // Селектор спортивных категорий с аналоговым Edge-Fade затуханием
            CircaEdgeFade(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: SportType.values.map((sport) {
                    final isSelected = _selectedSport == sport;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: isSelected,
                        showCheckmark: false,
                        avatar: Icon(
                          sport.icon,
                          size: 16,
                          color: isSelected ? Colors.white : palette.secondary,
                        ),
                        label: Text(
                          sport.localizedTitle(language.code),
                          style: TextStyle(
                            color: isSelected ? Colors.white : palette.fg,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selectedColor: AppColors.amber,
                        backgroundColor: palette.raised,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isSelected ? AppColors.amber : AppColors.line),
                        ),
                        onSelected: (selected) {
                          if (selected && !_isWorkoutActive) {
                            setState(() => _selectedSport = sport);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: 16),

            // Карточка активной сессии (Live Workout Banner)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isWorkoutActive
                                  ? (_isWorkoutPaused ? AppColors.amber : AppColors.sage)
                                  : AppColors.muted,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            _isWorkoutActive
                                ? (_isWorkoutPaused ? AppLocaleNotifier.pick('Пауза', 'Пауза', 'Paused') : AppLocaleNotifier.pick('Тренировка', 'Машыгуу', 'Workout'))
                                : AppLocaleNotifier.pick('Готов к старту', 'Стартка даяр', 'Ready'),
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _selectedSport.title.toString(),
                        style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),

                  if (_isWorkoutActive) ...[
                    // Крупный таймер
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTimer(_elapsedSeconds),
                          style: TextStyle(
                            color: palette.fg,
                            fontSize: 44,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.rose.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.favorite, color: AppColors.rose, size: 16),
                              SizedBox(width: 6),
                              Text(
                                '$currentBpm bpm',
                                style: TextStyle(color: AppColors.rose, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Метрики в реальном времени
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.raised,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('КАЛОРИИ', style: TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.w600)),
                                SizedBox(height: 2),
                                Text('$_caloriesBurned ккал', style: TextStyle(color: palette.fg, fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        if (_selectedSport.hasDistance) ...[
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.raised,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(language==AppLanguage.kyrgyz?'Аралык':'Дистанция', style: TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.w600)),
                                  SizedBox(height: 2),
                                  Text('${_distanceKm.toStringAsFixed(2)} км', style: TextStyle(color: palette.fg, fontSize: 14, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.raised,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ПИК ПУЛЬСА', style: TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.w600)),
                                SizedBox(height: 2),
                                Text('$_peakHr bpm', style: TextStyle(color: palette.fg, fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Кнопки управления тренировкой
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _togglePause,
                            icon: Icon(_isWorkoutPaused ? Icons.play_arrow : Icons.pause, size: 18),
                            label: Text(_isWorkoutPaused ? AppStrings.tr('sport_resume', language) : AppStrings.tr('sport_pause', language)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.fg,
                              side: BorderSide(color: AppColors.line),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _stopWorkout,
                            icon: Icon(Icons.stop, size: 18),
                            label: Text(AppStrings.tr('sport_finish', language)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.rose,
                              foregroundColor: AppColors.fg,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Состояние готовности к старту
                    Text(
                      AppLocaleNotifier.pick('Старт пишет пульс с часов в дневную нагрузку.', 'Старт сааттын пульсун күндүк жүктөмгө жазат.', 'Start logs watch heart rate into the day strain.'),
                      style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startWorkout,
                        icon: Icon(Icons.play_arrow, color: AppColors.stage),
                        label: Text(
                          '${AppStrings.tr('sport_start', language)} · ${_selectedSport.localizedTitle(language.code)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: -0.1),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.amber,
                          foregroundColor: AppColors.stage,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 14),

            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocaleNotifier.pick('Эта неделя', 'Бул апта', 'This week'), style: TextStyle(color: palette.secondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text('$_weekMinutes мин', style: TextStyle(color: palette.fg, fontSize: 28, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(AppLocaleNotifier.pick('Сумма ваших сессий за 7 дней.', '7 күндүк сессиялар.', 'Your sessions this week.'), style: TextStyle(color: palette.secondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // История тренировок
            Text(
              AppStrings.tr('sport_history', language),
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 8),

            if (_history.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Пока нет завершенных тренировок',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              )
            else
              ..._history.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.raised,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.sport.icon, color: AppColors.amber, size: 20),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.sport.title,
                                style: TextStyle(color: palette.fg, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '${item.durationFormatted} · ${item.calories} ккал · Ср: ${item.avgHr} bpm',
                                style: TextStyle(color: AppColors.muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '+${item.strain} Strain',
                              style: TextStyle(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '+${item.xpEarned} XP',
                              style: TextStyle(color: AppColors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
        );
      },
    );
  }
}
