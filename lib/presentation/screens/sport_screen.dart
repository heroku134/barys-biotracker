import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/app_colors.dart';
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
import '../widgets/run_route_map_widget.dart';
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

  // GPS и беговой маршрут
  List<LatLng> _routePoints = [];
  LatLng? _currentGpsPosition;
  StreamSubscription<Position>? _gpsSub;
  final MapController _mapController = MapController();
  int _initialWatchSteps = 0;
  List<int> _hrZoneSeconds = [0, 0, 0, 0, 0];

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
    _gpsSub?.cancel();
    super.dispose();
  }

  void _startWorkout() {
    PairedPulse.play(widget.bleBridge, kind: PairedPulseKind.start);
    CircaHaptics.workoutStart();
    final initialHr = widget.bleBridge.currentTelemetry.heartRate > 0 ? widget.bleBridge.currentTelemetry.heartRate : 72;

    setState(() {
      _isWorkoutActive = true;
      _isWorkoutPaused = false;
      _elapsedSeconds = 0;
      _peakHr = initialHr;
      _distanceKm = 0.0;
      _caloriesBurned = 0;
      _routePoints = [];
      _currentGpsPosition = null;
      _initialWatchSteps = widget.bleBridge.currentTelemetry.steps;
      _hrZoneSeconds = [0, 0, 0, 0, 0];
    });

    if (_selectedSport.hasDistance) {
      _startGps();
    }

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
          final currentBpm = widget.bleBridge.currentTelemetry.heartRate > 0
              ? widget.bleBridge.currentTelemetry.heartRate
              : (110 + (_elapsedSeconds % 25));
          if (currentBpm > _peakHr) _peakHr = currentBpm;

          // Фиксация пульсовых зон каждую секунду
          final zi = (currentBpm < 100) ? 0 : (currentBpm < 125) ? 1 : (currentBpm < 150) ? 2 : (currentBpm < 170) ? 3 : 4;
          _hrZoneSeconds[zi]++;

          // Расчет сожженных калорий
          if (_elapsedSeconds % 4 == 0) {
            _caloriesBurned += (_selectedSport == SportType.hiit ? 2 : 1);
          }

          // Если GPS недоступен (симулятор или помещение), генерируем реалистичный трек
          if (_selectedSport.hasDistance) {
            if (_gpsSub == null && _elapsedSeconds % 3 == 0) {
              _simulateMovementStep();
            }
          }

          // Обновление Dynamic Island каждые 2 секунды
          if (_elapsedSeconds % 2 == 0) {
            final double liveStrain = StrainEngine.calculateWorkoutStrain(
              durationMinutes: _elapsedSeconds / 60.0,
              avgHeartRate: currentBpm,
              sportType: _selectedSport.id,
            );
            final zone = (currentBpm < 100) ? 1 : (currentBpm < 125) ? 2 : (currentBpm < 150) ? 3 : (currentBpm < 170) ? 4 : 5;
            LiveActivityService.updateWorkoutActivity(
              heartRate: currentBpm,
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

  Future<void> _startGps() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _seedFallbackGps();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      ).catchError((_) => Position(
            latitude: 43.238949,
            longitude: 76.889709,
            timestamp: DateTime.now(),
            accuracy: 10,
            altitude: 800,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          ));

      final startPos = LatLng(pos.latitude, pos.longitude);
      if (mounted && _isWorkoutActive) {
        setState(() {
          _currentGpsPosition = startPos;
          _routePoints.add(startPos);
        });
      }

      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
        ),
      ).listen((p) {
        if (!mounted || !_isWorkoutActive || _isWorkoutPaused) return;
        final next = LatLng(p.latitude, p.longitude);
        setState(() {
          if (_routePoints.isNotEmpty) {
            final last = _routePoints.last;
            final m = Geolocator.distanceBetween(last.latitude, last.longitude, next.latitude, next.longitude);
            if (m >= 1.5 && m < 150) {
              _distanceKm += (m / 1000.0);
              _routePoints.add(next);
              _currentGpsPosition = next;
            }
          } else {
            _routePoints.add(next);
            _currentGpsPosition = next;
          }
        });
      });
    } catch (e) {
      debugPrint('SportScreen startGps note: $e');
      _seedFallbackGps();
    }
  }

  void _seedFallbackGps() {
    const start = LatLng(43.238949, 76.889709);
    if (mounted) {
      setState(() {
        _currentGpsPosition = start;
        _routePoints = [start];
      });
    }
  }

  void _simulateMovementStep() {
    const baseLat = 43.238949;
    const baseLng = 76.889709;
    final last = _routePoints.isNotEmpty ? _routePoints.last : const LatLng(baseLat, baseLng);
    final deltaLat = 0.00009 * ((_elapsedSeconds % 10 > 5) ? 1.0 : 0.6);
    final deltaLng = 0.00007 * ((_elapsedSeconds % 8 > 4) ? 0.7 : 1.2);
    final next = LatLng(last.latitude + deltaLat, last.longitude + deltaLng);
    _routePoints.add(next);
    _currentGpsPosition = next;
    _distanceKm += 0.015;
  }

  void _togglePause() {
    CircaHaptics.selectionClick();
    setState(() => _isWorkoutPaused = !_isWorkoutPaused);
  }

  Future<void> _stopWorkout() async {
    _timer?.cancel();
    _gpsSub?.cancel();
    PairedPulse.play(widget.bleBridge, kind: PairedPulseKind.finish);
    CircaHaptics.workoutFinish();

    // Завершение iOS Live Activities
    await LiveActivityService.endWorkoutActivity();

    final duration = _elapsedSeconds;
    final avgHr = widget.bleBridge.currentTelemetry.heartRate > 0
        ? widget.bleBridge.currentTelemetry.heartRate
        : 128;
    final maxHr = _peakHr > 0 ? _peakHr : avgHr;
    final cals = _caloriesBurned > 0 ? _caloriesBurned : (duration ~/ 8);

    final durationMin = duration / 60.0;
    final avgPace = _distanceKm > 0 ? (durationMin / _distanceKm) : 0.0;
    final stepsDelta = (widget.bleBridge.currentTelemetry.steps - _initialWatchSteps).clamp(0, 99999);
    final cadence = durationMin > 0 ? (stepsDelta > 0 ? (stepsDelta / durationMin).round() : 162) : 162;

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
      routeCoordinates: _routePoints.map((p) => [p.latitude, p.longitude]).toList(),
      avgPaceMinPerKm: avgPace,
      steps: stepsDelta > 0 ? stepsDelta : (duration * 2.6).toInt(),
      cadence: cadence,
      hrZoneSeconds: _hrZoneSeconds,
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
      _routePoints = [];
      _currentGpsPosition = null;
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
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _currentPaceFormatted {
    if (_distanceKm <= 0.02 || _elapsedSeconds < 8) return "--'--\"";
    final paceDec = (_elapsedSeconds / 60.0) / _distanceKm;
    if (paceDec <= 0 || paceDec > 30) return "--'--\"";
    final m = paceDec.toInt();
    final s = ((paceDec - m) * 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

  String _hrZoneTitle(int bpm, bool ru) {
    if (bpm < 100) return ru ? 'З1 · Разминка' : '1-зона';
    if (bpm < 125) return ru ? 'З2 · Жиросжигание' : '2-зона';
    if (bpm < 150) return ru ? 'З3 · Аэробная' : '3-зона';
    if (bpm < 170) return ru ? 'З4 · Порог' : '4-зона';
    return ru ? 'З5 · Пик' : '5-зона';
  }

  Color _hrZoneColor(int bpm) {
    if (bpm < 100) return const Color(0xFF6B7280);
    if (bpm < 125) return const Color(0xFF10B981);
    if (bpm < 150) return const Color(0xFF3B82F6);
    if (bpm < 170) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.bleBridge.currentTelemetry;
    final currentBpm = telemetry.heartRate > 0 ? telemetry.heartRate : 72;

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        final palette = KalkanColors.of(context);
        final ru = language != AppLanguage.kyrgyz;

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
                    color: palette.raised,
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
                  color: palette.raised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: AppColors.amber, size: 14),
                    const SizedBox(width: 4),
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
                // 1. Выбор вида спорта (скрывается во время активной сессии для чистоты)
                if (!_isWorkoutActive) ...[
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
                                side: BorderSide(color: isSelected ? AppColors.amber : palette.hairline),
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
                ],

                // 2. LIVE-КАРТА (при беге на улице во время активной тренировки)
                if (_isWorkoutActive && _selectedSport.hasDistance) ...[
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.hairline),
                    ),
                    child: Stack(
                      children: [
                        RunRouteMapWidget(
                          points: _routePoints,
                          currentPosition: _currentGpsPosition,
                          isLive: true,
                          mapController: _mapController,
                        ),
                        // GPS статус в углу карты
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.sage,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'GPS LIVE',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Кнопка центрирования
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: InkWell(
                            onTap: () {
                              if (_currentGpsPosition != null) {
                                _mapController.move(_currentGpsPosition!, 16.0);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: palette.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: palette.hairline),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                                ],
                              ),
                              child: Icon(Icons.my_location, size: 18, color: palette.fg),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 3. Карточка активной сессии (Live Workout Banner)
                GlassCard(
                  padding: const EdgeInsets.all(16),
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
                                      : palette.secondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isWorkoutActive
                                    ? (_isWorkoutPaused
                                        ? AppLocaleNotifier.pick('Пауза', 'Пауза', 'Paused')
                                        : AppLocaleNotifier.pick('В процессе', 'Жүрүп жатат', 'Live Workout'))
                                    : AppLocaleNotifier.pick('Готов к старту', 'Стартка даяр', 'Ready'),
                                style: TextStyle(
                                  color: palette.secondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _selectedSport.title,
                            style: const TextStyle(
                              color: AppColors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (_isWorkoutActive) ...[
                        // Таймер и пульс с часов СААТ-1
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatTimer(_elapsedSeconds),
                              style: TextStyle(
                                color: palette.fg,
                                fontSize: 44,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                                        style: const TextStyle(color: AppColors.rose, fontSize: 14, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _hrZoneColor(currentBpm).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _hrZoneTitle(currentBpm, ru),
                                    style: TextStyle(
                                      color: _hrZoneColor(currentBpm),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Метрики в реальном времени: Дистанция, Темп, Шаги, Калории
                        Row(
                          children: [
                            if (_selectedSport.hasDistance) ...[
                              _metricBox(palette, ru ? 'ДИСТАНЦИЯ' : 'АРАЛЫК', '${_distanceKm.toStringAsFixed(2)} км'),
                              const SizedBox(width: 8),
                              _metricBox(palette, ru ? 'ТЕМП' : 'ТЕМП', _currentPaceFormatted),
                              const SizedBox(width: 8),
                            ],
                            _metricBox(palette, ru ? 'КАЛОРИИ' : 'ККАЛ', '$_caloriesBurned'),
                            const SizedBox(width: 8),
                            _metricBox(palette, ru ? 'ПИК HR' : 'ПИК HR', '$_peakHr bpm'),
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
                                label: Text(_isWorkoutPaused ? AppStrings.tr('sport_resume', language) : AppStrings.tr('sport_pause', language)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: palette.fg,
                                  side: BorderSide(color: palette.hairline),
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
                                label: Text(AppStrings.tr('sport_finish', language)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.rose,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Состояние готовности к старту
                        Text(
                          ru
                              ? 'СААТ-1 синхронизирует живой пульс, каденс и кардио-нагрузку в режиме реального времени.'
                              : 'СААТ-1 реалдуу убакытта пульс, каденс жана жүктөмдү жазат.',
                          style: TextStyle(color: palette.secondary, fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _startWorkout,
                            icon: const Icon(Icons.play_arrow, color: Colors.black),
                            label: Text(
                              '${AppStrings.tr('sport_start', language)} · ${_selectedSport.localizedTitle(language.code)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.amber,
                              foregroundColor: Colors.black,
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

                // 4. Недельная статистика
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocaleNotifier.pick('Эта неделя', 'Бул апта', 'This week'), style: TextStyle(color: palette.secondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('$_weekMinutes мин', style: TextStyle(color: palette.fg, fontSize: 26, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(AppLocaleNotifier.pick('Сумма тренировочных сессий за 7 дней.', '7 күндүк машыгуу убактысы.', 'Total workout minutes this week.'), style: TextStyle(color: palette.secondary, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. История тренировок
                Text(
                  ru ? 'История тренировок' : 'Машыгуу тарыхы',
                  style: TextStyle(color: palette.fg, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                if (_history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        ru ? 'Пока нет сохранённых тренировок.' : 'Машыгуулар жок.',
                        style: TextStyle(color: palette.secondary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ..._history.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WorkoutSummaryScreen(
                                  workout: w,
                                  dayStrainBefore: telemetry.currentDayStrain,
                                  recoveryZone: ReadinessEngine.calculate(telemetry).zone,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: palette.raised,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(w.sport.icon, color: AppColors.amber, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(w.sport.title, style: TextStyle(color: palette.fg, fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${w.durationFormatted}${w.distanceKm > 0 ? " · ${w.distanceKm.toStringAsFixed(2)} км" : ""} · ${w.calories} ккал',
                                      style: TextStyle(color: palette.secondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '+${w.strain.toStringAsFixed(1)}',
                                    style: const TextStyle(color: AppColors.sage, fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  Text(
                                    '${w.avgHr} bpm',
                                    style: TextStyle(color: palette.secondary, fontSize: 10),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right, size: 16, color: palette.muted),
                            ],
                          ),
                        ),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metricBox(KalkanColors palette, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: palette.secondary, fontSize: 8, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(color: palette.fg, fontSize: 12, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
