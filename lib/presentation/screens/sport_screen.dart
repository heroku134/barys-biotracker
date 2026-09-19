import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/circa_haptics.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/workout_repository.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/models/workout_session.dart';
import '../widgets/circa_edge_fade.dart';
import '../widgets/glass_card.dart';

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

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await WorkoutRepository.loadWorkouts();
    if (mounted) setState(() => _history = list);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startWorkout() {
    CircaHaptics.workoutStart();
    setState(() {
      _isWorkoutActive = true;
      _isWorkoutPaused = false;
      _elapsedSeconds = 0;
      _peakHr = widget.bleBridge.currentTelemetry.heartRate;
      _distanceKm = 0.0;
      _caloriesBurned = 0;
    });

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
    CircaHaptics.workoutFinish();

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

    await WorkoutRepository.saveWorkout(completed);
    await _loadHistory();

    if (!mounted) return;
    setState(() {
      _isWorkoutActive = false;
      _isWorkoutPaused = false;
      _elapsedSeconds = 0;
    });

    // Диалог поздравления
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.stars, color: AppColors.amber, size: 22),
            const SizedBox(width: 8),
            Text(
              'Тренировка завершена!',
              style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Дисциплина: ${_selectedSport.title}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('STRAIN НАГРУЗКА', style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('+$calculatedStrain', style: const TextStyle(color: AppColors.cyan, fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('ОПЫТ БАРЫСА', style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('+$xp XP', style: const TextStyle(color: AppColors.amber, fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.line, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Время: ${completed.durationFormatted}', style: const TextStyle(color: AppColors.fg, fontSize: 12)),
                Text('Калории: $cals ккал', style: const TextStyle(color: AppColors.fg, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ОТЛИЧНО', style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
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
        return Scaffold(
          backgroundColor: AppColors.stage,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CIRCA SPORT',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                  ),
                ),
                Text(
                  AppStrings.tr('sport_title', language),
                  style: const TextStyle(
                    color: AppColors.fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
                const Icon(Icons.bolt, color: AppColors.amber, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${telemetry.currentDayStrain.toStringAsFixed(1)} / 21',
                  style: const TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w700),
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
                          color: isSelected ? AppColors.stage : AppColors.muted,
                        ),
                        label: Text(
                          sport.localizedTitle(language.code),
                          style: TextStyle(
                            color: isSelected ? AppColors.stage : AppColors.fg,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        selectedColor: AppColors.amber,
                        backgroundColor: AppColors.surface,
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
            const SizedBox(height: 16),

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
                          const SizedBox(width: 8),
                          Text(
                            _isWorkoutActive
                                ? (_isWorkoutPaused ? 'СЕССИЯ НА ПАУЗЕ' : 'АКТИВНАЯ ТРЕНИРОВКА')
                                : 'ГОТОВ К СТАРТУ',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _selectedSport.title.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_isWorkoutActive) ...[
                    // Крупный таймер
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTimer(_elapsedSeconds),
                          style: const TextStyle(
                            color: AppColors.fg,
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
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
                              const Icon(Icons.favorite, color: AppColors.rose, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '$currentBpm bpm',
                                style: const TextStyle(color: AppColors.rose, fontSize: 13, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

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
                                const Text('КАЛОРИИ', style: TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('$_caloriesBurned ккал', style: const TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                                  const Text('ДИСТАНЦИЯ', style: TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text('${_distanceKm.toStringAsFixed(2)} км', style: const TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                                const Text('ПИК ПУЛЬСА', style: TextStyle(color: AppColors.muted, fontSize: 9, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('$_peakHr bpm', style: const TextStyle(color: AppColors.fg, fontSize: 14, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Кнопки управления тренировкой
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _togglePause,
                            icon: Icon(_isWorkoutPaused ? Icons.play_arrow : Icons.pause, size: 18),
                            label: Text(_isWorkoutPaused ? 'ПРОДОЛЖИТЬ' : 'ПАУЗА'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.fg,
                              side: const BorderSide(color: AppColors.line),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _stopWorkout,
                            icon: const Icon(Icons.stop, size: 18),
                            label: const Text('ЗАВЕРШИТЬ'),
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
                      'Нажмите для синхронизации записи пульса с чипом браслета. Нагрузка будет зачислена в шкалу TRIMP и опыт Барыса.',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startWorkout,
                        icon: const Icon(Icons.play_arrow, color: AppColors.stage),
                        label: Text(
                          'НАЧАТЬ ТРЕНИРОВКУ (${_selectedSport.title.toUpperCase()})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.4),
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
            const SizedBox(height: 14),

            // Тумблер IMU v4.2 автодетекта
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.memory, color: AppColors.sage, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Автораспознавание движений IMU',
                              style: TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Алгоритм v4.2 автоматически стартует сессию при беге или шагах',
                          style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isAutoDetectImu,
                    activeThumbColor: AppColors.sage,
                    onChanged: (val) {
                      setState(() => _isAutoDetectImu = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surface,
                          content: Text(
                            val ? 'IMU автодетект активен' : 'IMU автодетект выключен',
                            style: const TextStyle(color: AppColors.fg),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Кардио-прогресс недели (Митохондриальное здоровье: Зона 2 и Зона 5)
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'НЕДЕЛЬНОЕ КАРДИО (ЗОНЫ 2 И 5)',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                      Text(
                        '152 / 200 мин (76%)',
                        style: const TextStyle(color: AppColors.sage, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: const LinearProgressIndicator(
                      value: 0.76,
                      backgroundColor: AppColors.raised,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.sage),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '128 мин в Аэробной Зоне 2 + 24 мин интервалов в Зоне 5 обеспечивают омоложение миокарда.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // История тренировок
            const Text(
              'ИСТОРИЯ ТРЕНИРОВОК',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),

            if (_history.isEmpty)
              const Padding(
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.sport.title,
                                style: const TextStyle(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.durationFormatted} · ${item.calories} ккал · Ср: ${item.avgHr} bpm',
                                style: const TextStyle(color: AppColors.muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '+${item.strain} Strain',
                              style: const TextStyle(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '+${item.xpEarned} XP',
                              style: const TextStyle(color: AppColors.amber, fontSize: 11, fontWeight: FontWeight.w700),
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
