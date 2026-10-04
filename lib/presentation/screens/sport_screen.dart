import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/app_colors.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../../core/app_typography.dart';
import '../../core/circa_haptics.dart';
import '../../data/services/paired_pulse.dart';
import '../../data/ble/ute_ble_bridge.dart';
import '../../data/storage/workout_repository.dart';
import '../../data/storage/local_day_strain.dart';
import '../../data/storage/user_profile_repository.dart';
import '../../domain/intelligence/readiness_engine.dart';
import 'workout_summary_screen.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/workout_session.dart';
import '../widgets/active_workout_panel.dart';
import '../widgets/glass_card.dart';
import '../widgets/kalkan_ui.dart';
import '../widgets/kalkan_chrome.dart';
import '../widgets/sport_category_selector.dart';
import '../widgets/workout_history_card.dart';
import '../../data/services/live_activity_service.dart';
import '../../data/services/system_notification_service.dart';
import '../../data/services/health_sync_service.dart';

class SportScreen extends StatefulWidget {
  final UteBleBridge bleBridge;

  const SportScreen({super.key, required this.bleBridge});

  @override
  State<SportScreen> createState() => _SportScreenState();
}

class _SportScreenState extends State<SportScreen> {
  SportType _selectedSport = SportType.runOutdoor;
  SportCategoryFilter _categoryFilter = SportCategoryFilter.all;
  UserProfile _userProfile = const UserProfile();
  List<CompletedWorkout> _history = [];

  // Состояние активной тренировки
  bool _isWorkoutActive = false;
  bool _isWorkoutPaused = false;
  bool _isFinishingWorkout = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  int _peakHr = 0;
  double _distanceKm = 0.0;
  int _caloriesBurned = 0;
  StreamSubscription? _bleSub;

  // Таймер отдыха между подходами (для силовых и зальных тренировок)
  int _restSecondsRemaining = 0;
  Timer? _restTimer;

  // GPS и беговой маршрут
  List<LatLng> _routePoints = [];
  LatLng? _currentGpsPosition;
  StreamSubscription<Position>? _gpsSub;
  final MapController _mapController = MapController();
  int _initialWatchSteps = 0;
  List<int> _hrZoneSeconds = [0, 0, 0, 0, 0];
  int _hrSum = 0;
  int _hrSamples = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    UserProfileRepository.loadProfile().then((p) {
      if (mounted) setState(() => _userProfile = p);
    });
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

  bool _isHealthSyncing = false;

  Future<void> _syncWithHealthKit() async {
    if (_isHealthSyncing) return;
    CircaHaptics.selectionClick();
    setState(() => _isHealthSyncing = true);
    try {
      final report = await HealthSyncService.syncAll();
      await _loadHistory();
      if (!mounted) return;
      CircaHaptics.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KalkanUi.cardRadius)),
          content: Row(
            children: [
              const Icon(Icons.cloud_done_outlined, color: AppColors.sage, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  report.importedWorkoutsCount > 0
                      ? '${AppLocaleNotifier.pick("Импортировано", "Импорттолду", "Imported")}: +${report.importedWorkoutsCount} (${report.importedWorkouts.map((w) => w.sourceDisplayName).toSet().join(', ')}) · +${report.addedStrain.toStringAsFixed(1)} Strain'
                      : AppLocaleNotifier.pick('Все внешние тренировки синхронизированы', 'Бардык машыгуулар синхрондоштурулду', 'All external workouts are up to date'),
                  style: AppTypography.bodyMuted(KalkanColors.of(context).fg).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Sync health error: $e');
    } finally {
      if (mounted) setState(() => _isHealthSyncing = false);
    }
  }

  List<int> get _weekZoneSeconds =>
      WorkoutRepository.weeklyZoneSecondsFrom(_history);

  int get _weekZone2Minutes =>
      _weekZoneSeconds.length > 1 ? _weekZoneSeconds[1] ~/ 60 : 0;

  int get _weekZone5Minutes =>
      _weekZoneSeconds.length > 4 ? _weekZoneSeconds[4] ~/ 60 : 0;

  List<SportType> get _filteredSports {
    switch (_categoryFilter) {
      case SportCategoryFilter.outdoor:
        return SportType.values.where((s) => s.isOutdoor).toList();
      case SportCategoryFilter.indoor:
        return SportType.values.where((s) => s.isIndoor).toList();
      case SportCategoryFilter.all:
        return SportType.values;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
    _bleSub?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    CircaHaptics.selectionClick();
    setState(() => _restSecondsRemaining = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_restSecondsRemaining > 1) {
          _restSecondsRemaining--;
        } else {
          _restSecondsRemaining = 0;
          t.cancel();
          CircaHaptics.success();
        }
      });
    });
  }

  void _startWorkout() {
    PairedPulse.play(widget.bleBridge, kind: PairedPulseKind.start);
    CircaHaptics.workoutStart();
    final rawHr = widget.bleBridge.currentTelemetry.heartRate;
    final initialHr = rawHr > 0 ? rawHr : 0;

    setState(() {
      _isWorkoutActive = true;
      _isWorkoutPaused = false;
      _isFinishingWorkout = false;
      _elapsedSeconds = 0;
      _peakHr = initialHr;
      _distanceKm = 0.0;
      _caloriesBurned = 0;
      _routePoints = [];
      _currentGpsPosition = null;
      _initialWatchSteps = widget.bleBridge.currentTelemetry.steps;
      _hrZoneSeconds = [0, 0, 0, 0, 0];
      _hrSum = 0;
      _hrSamples = 0;
      _restSecondsRemaining = 0;
    });

    // Запуск GPS ТОЛЬКО для тренировок на открытом воздухе
    if (_selectedSport.needsGps) {
      _startGps();
    }

    // Запуск iOS Live Activities & Dynamic Island
    LiveActivityService.startWorkoutActivity(
      workoutName: _selectedSport.title,
      workoutType: _selectedSport.id,
      initialHeartRate: initialHr,
      heartRateZone: initialHr > 0 ? _userProfile.getHeartRateZone(initialHr) + 1 : 0,
      currentStrain: 0.0,
      activeCalories: 0,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isWorkoutPaused) {
        setState(() {
          _elapsedSeconds++;
          final currentBpm = widget.bleBridge.currentTelemetry.heartRate;
          if (currentBpm > 0) {
            if (currentBpm > _peakHr) _peakHr = currentBpm;
            _hrSum += currentBpm;
            _hrSamples++;

            // Фиксация пульсовых зон по формуле 220 - age
            final zi = _userProfile.getHeartRateZone(currentBpm);
            _hrZoneSeconds[zi]++;

            // Расчет сожженных калорий по физиологической формуле Keytel (по скользящему среднему ЧСС)
            _caloriesBurned = _userProfile.calculateCaloriesBurned(
              durationSeconds: _elapsedSeconds,
              avgHr: _hrSum ~/ _hrSamples,
            );
          }

          // Обновление Dynamic Island каждые 2 секунды
          if (_elapsedSeconds % 2 == 0) {
            final double liveStrain = currentBpm > 0
                ? StrainEngine.calculateWorkoutStrain(
                    durationMinutes: _elapsedSeconds / 60.0,
                    avgHeartRate: currentBpm,
                    sportType: _selectedSport.id,
                  )
                : 0.0;
            final zone = currentBpm > 0 ? _userProfile.getHeartRateZone(currentBpm) + 1 : 0;
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
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }

      // Try initial position fix (non-blocking if slow or indoors)
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
        final startPos = LatLng(pos.latitude, pos.longitude);
        if (mounted && _isWorkoutActive) {
          setState(() {
            _currentGpsPosition = startPos;
            if (_routePoints.isEmpty) {
              _routePoints.add(startPos);
            }
          });
        }
      } catch (e) {
        debugPrint('SportScreen initial position fix skipped or timed out: $e');
      }

      // Platform-specific settings enabling continuous background tracking
      late final LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.fitness,
          distanceFilter: 3,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
          intervalDuration: const Duration(seconds: 2),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'KALKAN SPORT',
            notificationText: 'Запись маршрута тренировки...',
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
        );
      }

      _gpsSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
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
      debugPrint('SportScreen startGps error: $e');
    }
  }

  void _togglePause() {
    CircaHaptics.selectionClick();
    setState(() {
      _isWorkoutPaused = !_isWorkoutPaused;
      if (_isWorkoutPaused) {
        _gpsSub?.pause();
      } else {
        _gpsSub?.resume();
      }
    });
  }

  Future<void> _stopWorkout() async {
    if (_isFinishingWorkout) return;
    setState(() => _isFinishingWorkout = true);

    try {
      _timer?.cancel();
      _timer = null;
      _restTimer?.cancel();
      _restTimer = null;
      try {
        await _gpsSub?.cancel();
        _gpsSub = null;
      } catch (_) {}

      try {
        PairedPulse.play(widget.bleBridge, kind: PairedPulseKind.finish);
        CircaHaptics.workoutFinish();
      } catch (_) {}

      // Безопасное завершение iOS Live Activities
      try {
        await LiveActivityService.endWorkoutActivity();
      } catch (_) {}

      final duration = _elapsedSeconds;
      final avgHr = _hrSamples > 0
          ? _hrSum ~/ _hrSamples
          : widget.bleBridge.currentTelemetry.heartRate;
      final maxHr = _peakHr > 0 ? _peakHr : avgHr;
      final cals = _caloriesBurned > 0
          ? _caloriesBurned
          : (avgHr > 0 ? _userProfile.calculateCaloriesBurned(durationSeconds: duration, avgHr: avgHr) : 0);

      final durationMin = duration / 60.0;
      final avgPace = (_selectedSport.hasDistance && _distanceKm > 0)
          ? (durationMin / _distanceKm)
          : 0.0;

      // Реальные шаги без искусственного каденса
      final stepsDelta = (widget.bleBridge.currentTelemetry.steps - _initialWatchSteps).clamp(0, 99999);
      final int finalSteps = stepsDelta;
      final int finalCadence = (durationMin > 0 && finalSteps > 0) ? (finalSteps / durationMin).round() : 0;

      // Расчет заработанного Strain
      final double calculatedStrain = StrainEngine.calculateWorkoutStrain(
        durationMinutes: duration / 60.0,
        avgHeartRate: avgHr,
        sportType: _selectedSport.id,
      );

      // Начисление опыта Барысу
      final xp = AvatarManager.recordWorkout(calculatedStrain);

      // Координаты маршрута ТОЛЬКО для тренировок на улице!
      // Для силовых и зала - пустой список, никаких фейковых точек!
      final List<List<double>> coords = (_selectedSport.needsGps && _routePoints.isNotEmpty)
          ? _routePoints.map((p) => [p.latitude, p.longitude]).toList()
          : const [];

      final finalDistance = _selectedSport.hasDistance
          ? double.parse(_distanceKm.toStringAsFixed(2))
          : 0.0;

      final completed = CompletedWorkout(
        id: 'w_${DateTime.now().millisecondsSinceEpoch}',
        sport: _selectedSport,
        startedAt: DateTime.now().subtract(Duration(seconds: duration)),
        durationSeconds: duration,
        calories: cals,
        distanceKm: finalDistance,
        avgHr: avgHr,
        maxHr: maxHr,
        strain: calculatedStrain,
        xpEarned: xp,
        routeCoordinates: coords,
        avgPaceMinPerKm: avgPace,
        steps: finalSteps,
        cadence: finalCadence,
        hrZoneSeconds: _hrZoneSeconds,
      );

      final dayBefore = widget.bleBridge.currentTelemetry.currentDayStrain > 0
          ? widget.bleBridge.currentTelemetry.currentDayStrain
          : (StrainEngine.calculateStrainFromZones(
                  widget.bleBridge.currentTelemetry.zoneMinutes) +
              LocalDayStrain.current());
      final zone = ReadinessEngine.calculate(widget.bleBridge.currentTelemetry).zone;

      LocalDayStrain.add(calculatedStrain);
      final dayAfter = dayBefore + calculatedStrain;
      final rec = ReadinessEngine.calculate(widget.bleBridge.currentTelemetry);
      try {
        SystemNotificationService.notifyWorkoutEnd(
          sessionStrain: calculatedStrain,
          dayStrain: dayAfter,
          targetMax: StrainEngine.evaluate(currentStrain: dayAfter, recoveryZone: rec.zone).targetStrainMax,
        );
      } catch (_) {}

      try {
        await WorkoutRepository.saveWorkout(completed);
        await HealthSyncService.exportWorkoutToHealth(
          workout: completed,
          strain: calculatedStrain,
          activeCalories: cals,
        );
        await _loadHistory();
      } catch (e) {
        debugPrint('Workout save error: $e');
      }

      if (!mounted) return;
      setState(() {
        _isWorkoutActive = false;
        _isWorkoutPaused = false;
        _elapsedSeconds = 0;
        _routePoints = [];
        _currentGpsPosition = null;
        _restSecondsRemaining = 0;
      });

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkoutSummaryScreen(
              workout: completed,
              dayStrainBefore: dayBefore,
              recoveryZone: zone,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFinishingWorkout = false);
      }
    }
  }

  String get _currentPaceFormatted {
    if (_distanceKm <= 0.02 || _elapsedSeconds < 8) return "--'--\"";
    final paceDec = (_elapsedSeconds / 60.0) / _distanceKm;
    if (paceDec <= 0 || paceDec > 30) return "--'--\"";
    var m = paceDec.toInt();
    var s = ((paceDec - m) * 60).round();
    if (s >= 60) { m += 1; s -= 60; }
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.bleBridge.currentTelemetry;
    final currentBpm = telemetry.heartRate;
    final displayDayStrain = telemetry.currentDayStrain > 0
        ? telemetry.currentDayStrain
        : (StrainEngine.calculateStrainFromZones(telemetry.zoneMinutes) +
            LocalDayStrain.current());

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocaleNotifier.instance,
      builder: (context, language, _) {
        final palette = KalkanColors.of(context);

        return Scaffold(
          backgroundColor: palette.bg,
          appBar: KalkanAppBar(
            eyebrow: AppStrings.tr('nav_sport', language),
            title: AppStrings.tr('sport_title', language),
            actions: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                  border: Border.all(color: palette.hairline, width: KalkanUi.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, color: AppColors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${displayDayStrain.toStringAsFixed(1)} / 21',
                      style: AppTypography.caption(palette.fg).copyWith(fontWeight: FontWeight.w600),
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
                  SportCategoryFilterBar(
                    selectedFilter: _categoryFilter,
                    onFilterChanged: (filter) => setState(() => _categoryFilter = filter),
                  ),
                  const SizedBox(height: 12),
                  SportHorizontalCarousel(
                    sports: _filteredSports,
                    selectedSport: _selectedSport,
                    language: language,
                    onSportSelected: (sport) {
                      if (!_isWorkoutActive) {
                        setState(() => _selectedSport = sport);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // 2. Панель тренировки (активная сессия с GPS / готовность к старту)
                ActiveWorkoutPanel(
                  selectedSport: _selectedSport,
                  isWorkoutActive: _isWorkoutActive,
                  isWorkoutPaused: _isWorkoutPaused,
                  isFinishingWorkout: _isFinishingWorkout,
                  elapsedSeconds: _elapsedSeconds,
                  currentBpm: currentBpm,
                  peakHr: _peakHr,
                  caloriesBurned: _caloriesBurned,
                  distanceKm: _distanceKm,
                  currentPaceFormatted: _currentPaceFormatted,
                  restSecondsRemaining: _restSecondsRemaining,
                  routePoints: _routePoints,
                  currentGpsPosition: _currentGpsPosition,
                  mapController: _mapController,
                  userProfile: _userProfile,
                  language: language,
                  onStartWorkout: _startWorkout,
                  onTogglePause: _togglePause,
                  onStopWorkout: _stopWorkout,
                  onStartRestTimer: _startRestTimer,
                  onCancelRestTimer: () {
                    _restTimer?.cancel();
                    setState(() => _restSecondsRemaining = 0);
                  },
                ),
                const SizedBox(height: 14),

                // 4. Автораспознавание движений IMU
                GlassCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.memory, color: AppColors.sage, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocaleNotifier.pick('Автораспознавание движений IMU', 'IMU кыймылды автоматтык таануу', 'IMU Auto Movement Detection'),
                                  style: AppTypography.bodySemibold(palette.fg),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocaleNotifier.pick(
                                'Алгоритм v4.2 автоматически стартует сессию при беге или шагах',
                                'v4.2 алгоритми чуркоодо автоматтык түрдө баштайт',
                                'v4.2 algorithm auto-starts sessions on run or walking',
                              ),
                              style: AppTypography.caption(palette.secondary).copyWith(height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: true,
                        activeTrackColor: AppColors.sage.withValues(alpha: 0.5),
                        activeThumbColor: AppColors.sage,
                        onChanged: (val) {
                          CircaHaptics.selectionClick();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: palette.surface,
                              content: Text(
                                val
                                    ? AppLocaleNotifier.pick('IMU автодетект активен', 'IMU автодетект активдүү', 'IMU auto-detect active')
                                    : AppLocaleNotifier.pick('IMU автодетект выключен', 'IMU автодетект өчүрүлдү', 'IMU auto-detect disabled'),
                                style: AppTypography.body(palette.fg),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Недельное кардио (Зоны 2 и 5)
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocaleNotifier.pick('НЕДЕЛЬНОЕ КАРДИО (ЗОНЫ 2 И 5)', 'АПТАЛЫК КАРДИО (2 ЖАНА 5-ЗОНА)', 'WEEKLY CARDIO (ZONES 2 & 5)'),
                            style: AppTypography.monoLabel(palette.secondary),
                          ),
                          Text(
                            'З2 $_weekZone2Minutes мин · З5 $_weekZone5Minutes мин',
                            style: AppTypography.bodyMuted(AppColors.sage).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_weekZone2Minutes / 200).clamp(0.0, 1.0),
                          backgroundColor: palette.hairline,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sage),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocaleNotifier.pick(
                          '$_weekZone2Minutes мин в Аэробной Зоне 2 + $_weekZone5Minutes мин интервалов в Зоне 5 (цель З2: 200 мин/нед).',
                          'Аэробдук 2-зонадагы $_weekZone2Minutes мүнөт + 5-зонадагы $_weekZone5Minutes мүнөт интервалдар (максат З2: 200 мүн/апта).',
                          '$_weekZone2Minutes min in Aerobic Zone 2 + $_weekZone5Minutes min Zone 5 intervals (Z2 goal: 200 min/wk).',
                        ),
                        style: AppTypography.caption(palette.secondary).copyWith(height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5.1 Двусторонний обмен Apple Health / Health Connect / Strava / Garmin
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFC4C02).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                        ),
                        child: const Icon(Icons.sync_alt, color: Color(0xFFFC4C02), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  AppLocaleNotifier.pick('Apple Health & Strava', 'Apple Health жана Strava', 'Apple Health & Strava'),
                                  style: AppTypography.bodySemibold(palette.fg),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.sage.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(KalkanUi.progressRadius),
                                  ),
                                  child: Text(
                                    'AUTO SYNC',
                                    style: AppTypography.monoBadge.copyWith(color: AppColors.sage),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppLocaleNotifier.pick(
                                'Импорт заездов, заплывов и бега из Strava / Garmin в Strain',
                                'Strava / Garmin машыгууларын күндүк Strainге кошуу',
                                'Auto-import rides, swims & runs into daily Strain',
                              ),
                              style: AppTypography.caption(palette.secondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isHealthSyncing ? null : _syncWithHealthKit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.raised,
                          foregroundColor: palette.fg,
                          elevation: 0,
                          minimumSize: const Size(44, KalkanUi.minTapTarget),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                            side: BorderSide(color: palette.hairline, width: KalkanUi.hairline),
                          ),
                        ),
                        child: _isHealthSyncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amber),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh, size: 14, color: palette.fg),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppLocaleNotifier.pick('Синхр.', 'Синхр.', 'Sync'),
                                    style: AppTypography.caption(palette.fg).copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 6. История тренировок
                Text(
                  AppLocaleNotifier.pick('История тренировок', 'Машыгуу тарыхы', 'Workout History'),
                  style: AppTypography.bodySemibold(palette.fg),
                ),
                const SizedBox(height: 8),

                if (_history.isEmpty)
                  KalkanCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.strainBlue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                                border: Border.all(color: AppColors.strainBlue.withValues(alpha: 0.3), width: KalkanUi.hairline),
                              ),
                              child: const Icon(Icons.fitness_center_outlined, color: AppColors.strainBlue, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocaleNotifier.pick('ТРЕНИРОВКИ СААТ-1', 'СААТ-1 МАШЫГУУЛАРЫ', 'SAAT-1 WORKOUTS'),
                                    style: AppTypography.eyebrow(palette.secondary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppLocaleNotifier.pick('Нет сохранённых тренировок', 'Сакталган машыгуулар жок', 'No saved workouts'),
                                    style: AppTypography.bodySemibold(palette.fg),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppLocaleNotifier.pick(
                            'Запустите активность выше, чтобы часы СААТ-1 записали пульсовые зоны, калории и набранный Strain в дневник.',
                            'Пульс зоналарын жана Strain көрсөткүчүн сактоо үчүн жогору жактан машыгууну баштаңыз.',
                            'Start an activity above to track heart rate zones, calories, and accumulated strain with your SAAT-1 watch.',
                          ),
                          style: AppTypography.caption(palette.secondary).copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              CircaHaptics.selectionClick();
                              _startWorkout();
                            },
                            icon: const Icon(Icons.play_arrow, size: 16, color: AppColors.strainBlue),
                            label: Text(
                              AppLocaleNotifier.pick('Начать первую тренировку', 'Биринчи машыгууну баштоо', 'Start First Workout'),
                              style: const TextStyle(color: AppColors.strainBlue, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.strainBlue.withValues(alpha: 0.5), width: KalkanUi.hairline),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KalkanUi.controlRadius)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._history.map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: WorkoutHistoryCard(
                        workout: w,
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
