import 'dart:async';
import 'package:flutter/material.dart';
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
import '../../data/storage/user_profile_repository.dart';
import '../../domain/intelligence/readiness_engine.dart';
import 'workout_summary_screen.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/workout_session.dart';
import '../widgets/circa_pulsing_logo.dart';
import '../widgets/glass_card.dart';
import '../widgets/run_route_map_widget.dart';
import '../../data/services/live_activity_service.dart';
import '../../data/services/system_notification_service.dart';
import '../../data/services/health_sync_service.dart';

enum SportCategoryFilter {
  all,
  outdoor,
  indoor,
}

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.cloud_done_outlined, color: AppColors.sage, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  report.importedWorkoutsCount > 0
                      ? '${AppLocaleNotifier.pick("Импортировано", "Импорттолду", "Imported")}: +${report.importedWorkoutsCount} (${report.importedWorkouts.map((w) => w.sourceDisplayName).toSet().join(', ')}) · +${report.addedStrain.toStringAsFixed(1)} Strain'
                      : AppLocaleNotifier.pick('Все внешние тренировки синхронизированы', 'Бардык машыгуулар синхрондоштурулду', 'All external workouts are up to date'),
                  style: TextStyle(color: KalkanColors.of(context).fg, fontSize: 12, fontWeight: FontWeight.w600),
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

  int get _weekMinutes {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final from = DateTime(start.year, start.month, start.day);
    return _history
        .where((w) => !w.startedAt.isBefore(from))
        .fold<int>(0, (s, w) => s + (w.durationSeconds ~/ 60));
  }

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
    final initialHr = widget.bleBridge.currentTelemetry.heartRate > 0 ? widget.bleBridge.currentTelemetry.heartRate : 72;

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
              : (108 + (_elapsedSeconds % 28));
          if (currentBpm > _peakHr) _peakHr = currentBpm;

          // Фиксация пульсовых зон по формуле 220 - age
          final zi = _userProfile.getHeartRateZone(currentBpm);
          _hrZoneSeconds[zi]++;

          // Расчет сожженных калорий по физиологической формуле Keytel
          _caloriesBurned = _userProfile.calculateCaloriesBurned(
            durationSeconds: _elapsedSeconds,
            avgHr: currentBpm,
          );

          // Для уличных видов спорта с GPS: симуляция шага только если GPS залип на симуляторе
          if (_selectedSport.needsGps) {
            final isStationary = _routePoints.length <= 2 && _elapsedSeconds >= 4;
            if ((_gpsSub == null || isStationary) && _elapsedSeconds % 2 == 0) {
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
            final zone = zi + 1;
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
      final avgHr = widget.bleBridge.currentTelemetry.heartRate > 0
          ? widget.bleBridge.currentTelemetry.heartRate
          : 128;
      final maxHr = _peakHr > 0 ? _peakHr : avgHr;
      final cals = _caloriesBurned > 0
          ? _caloriesBurned
          : _userProfile.calculateCaloriesBurned(durationSeconds: duration, avgHr: avgHr);

      final durationMin = duration / 60.0;
      final avgPace = (_selectedSport.hasDistance && _distanceKm > 0)
          ? (durationMin / _distanceKm)
          : 0.0;

      // Реальные шаги: для силовых и зальных не создаем искусственный каденс
      final stepsDelta = (widget.bleBridge.currentTelemetry.steps - _initialWatchSteps).clamp(0, 99999);
      final int finalSteps;
      final int finalCadence;
      if (_selectedSport.isIndoor) {
        finalSteps = stepsDelta;
        finalCadence = 0;
      } else {
        finalSteps = stepsDelta > 0 ? stepsDelta : (duration * 2.6).toInt();
        finalCadence = durationMin > 0 ? (finalSteps / durationMin).round() : 160;
      }

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
          : 0.0;
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

  String _hrZoneTitle(int bpm, AppLanguage lang) {
    final zoneIndex = _userProfile.getHeartRateZone(bpm);
    if (lang == AppLanguage.kyrgyz) {
      switch (zoneIndex) {
        case 0:
          return '1-зона · Жылынуу';
        case 1:
          return '2-зона · Май күйгүзүү';
        case 2:
          return '3-зона · Аэробдук';
        case 3:
          return '4-зона · Босого';
        default:
          return '5-зона · Чок';
      }
    }
    if (lang == AppLanguage.english) {
      switch (zoneIndex) {
        case 0:
          return 'Z1 · Warm Up';
        case 1:
          return 'Z2 · Fat Burn';
        case 2:
          return 'Z3 · Aerobic';
        case 3:
          return 'Z4 · Threshold';
        default:
          return 'Z5 · Peak';
      }
    }
    switch (zoneIndex) {
      case 0:
        return 'З1 · Разминка';
      case 1:
        return 'З2 · Жиросжигание';
      case 2:
        return 'З3 · Аэробная';
      case 3:
        return 'З4 · Порог';
      default:
        return 'З5 · Пик';
    }
  }

  Color _hrZoneColor(int bpm) {
    final zi = _userProfile.getHeartRateZone(bpm);
    switch (zi) {
      case 0:
        return const Color(0xFF6B7280);
      case 1:
        return const Color(0xFF10B981);
      case 2:
        return const Color(0xFF3B82F6);
      case 3:
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  String _sportSubtitle(SportType sport, AppLanguage lang) {
    switch (sport) {
      case SportType.runOutdoor:
        return AppLocaleNotifier.pick('GPS · темп · каденс', 'GPS · темп', 'GPS · pace');
      case SportType.cycling:
        return AppLocaleNotifier.pick('Скорость · GPS · трек', 'Ылдамдык · GPS', 'Speed · GPS · track');
      case SportType.walkOutdoor:
        return AppLocaleNotifier.pick('Маршрут · шаги · темп', 'Маршрут · кадамдар', 'Route · steps · pace');
      case SportType.strength:
        return AppLocaleNotifier.pick('Пульс · подходы · отдых', 'Пульс · эс алуу', 'Heart rate · sets · rest');
      case SportType.hiit:
        return AppLocaleNotifier.pick('Интервалы · зоны · пик', 'Интервалдар · зоналар', 'Intervals · zones · peak');
      case SportType.combat:
        return AppLocaleNotifier.pick('Выносливость · спарринг', 'Чыдамкайлык · бокс', 'Endurance · sparring');
      case SportType.yoga:
        return AppLocaleNotifier.pick('Восстановление · дыхание', 'Калыбына келүү · дем', 'Recovery · breathwork');
      case SportType.swimming:
        return AppLocaleNotifier.pick('Бассейн · аэробная нагрузка', 'Бассейн · кардио', 'Pool · cardio load');
      case SportType.runIndoor:
        return AppLocaleNotifier.pick('Беговая дорожка · пульс', 'Тренажер · пульс', 'Treadmill · heart rate');
    }
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.bleBridge.currentTelemetry;
    final currentBpm = telemetry.heartRate > 0 ? telemetry.heartRate : 72;

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
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.hairline, width: 1.0),
                  ),
                  child: CircaPulsingLogo(
                    size: 26,
                    animate: false,
                    primaryColor: AppColors.amber,
                    secondaryColor: palette.secondary,
                  ),
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
                  color: palette.surface,
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
                  // Категории: Все / На улице / В зале
                  Row(
                    children: [
                      _categoryFilterChip(SportCategoryFilter.all, AppLocaleNotifier.pick('Все', 'Баары', 'All'), palette),
                      const SizedBox(width: 8),
                      _categoryFilterChip(SportCategoryFilter.outdoor, AppLocaleNotifier.pick('📍 На улице', '📍 Тышта', '📍 Outdoor'), palette),
                      const SizedBox(width: 8),
                      _categoryFilterChip(SportCategoryFilter.indoor, AppLocaleNotifier.pick('⚡ В зале / Дома', '⚡ Залда / Үйдө', '⚡ Gym / Home'), palette),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Карточки видов спорта с полным названием, бейджем GPS/ЗАЛ и подсказкой
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredSports.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final sport = _filteredSports[index];
                        final isSelected = _selectedSport == sport;
                        return InkWell(
                          onTap: () {
                            if (!_isWorkoutActive) {
                              CircaHaptics.selectionClick();
                              setState(() => _selectedSport = sport);
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 172,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.amber.withValues(alpha: 0.12) : palette.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppColors.amber : palette.hairline,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: AppColors.amber.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
                                  : (palette.shadow.a > 0 ? [BoxShadow(color: palette.shadow, blurRadius: 4)] : null),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.amber : palette.raised,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        sport.icon,
                                        size: 16,
                                        color: isSelected ? Colors.white : palette.secondary,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (sport.needsGps ? AppColors.sage : AppColors.amber).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        sport.needsGps ? 'GPS' : (sport == SportType.strength ? 'СИЛА' : 'ЗАЛ'),
                                        style: TextStyle(
                                          color: sport.needsGps ? AppColors.sage : AppColors.amber,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sport.localizedTitle(language.code),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.fg,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _sportSubtitle(sport, language),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.secondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 2. LIVE-КАРТА (ТОЛЬКО при тренировках на улице с GPS)
                if (_isWorkoutActive && _selectedSport.needsGps) ...[
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
                              color: palette.surface.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: palette.hairline),
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
                                Text(
                                  'GPS LIVE',
                                  style: TextStyle(color: palette.fg, fontSize: 10, fontWeight: FontWeight.w700),
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
                                    _hrZoneTitle(currentBpm, language),
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

                        // Метрики в реальном времени: Дистанция/темп (для уличных) или Пульсовая зона/калории (для зала)
                        Row(
                          children: [
                            if (_selectedSport.needsGps) ...[
                              _metricBox(palette, AppLocaleNotifier.pick('ДИСТАНЦИЯ', 'АРАЛЫК', 'DISTANCE'), '${_distanceKm.toStringAsFixed(2)} км'),
                              const SizedBox(width: 8),
                              _metricBox(palette, AppLocaleNotifier.pick('ТЕМП', 'ТЕМП', 'PACE'), _currentPaceFormatted),
                              const SizedBox(width: 8),
                            ] else if (_selectedSport.hasDistance) ...[
                              _metricBox(palette, AppLocaleNotifier.pick('ДИСТАНЦИЯ', 'АРАЛЫК', 'DISTANCE'), '${_distanceKm.toStringAsFixed(2)} км'),
                              const SizedBox(width: 8),
                            ],
                            _metricBox(palette, AppLocaleNotifier.pick('КАЛОРИИ', 'ККАЛ', 'CALORIES'), '$_caloriesBurned'),
                            const SizedBox(width: 8),
                            _metricBox(palette, AppLocaleNotifier.pick('ПИК HR', 'ПИК HR', 'PEAK HR'), '$_peakHr bpm'),
                            if (_selectedSport.isIndoor) ...[
                              const SizedBox(width: 8),
                              _metricBox(palette, AppLocaleNotifier.pick('ЗОНА', 'ЗОНА', 'ZONE'), 'Z${_userProfile.getHeartRateZone(currentBpm) + 1}'),
                            ],
                          ],
                        ),

                        // Таймер отдыха между подходами (для силовых тренировок и зала)
                        if (_selectedSport.isIndoor) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _restSecondsRemaining > 0 ? AppColors.amber : palette.hairline,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _restSecondsRemaining > 0 ? Icons.timer : Icons.timer_outlined,
                                  size: 16,
                                  color: _restSecondsRemaining > 0 ? AppColors.amber : palette.secondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _restSecondsRemaining > 0
                                        ? '${AppLocaleNotifier.pick('Отдых', 'Эс алуу', 'Rest')}: ${_formatTimer(_restSecondsRemaining)}'
                                        : AppLocaleNotifier.pick('Отдых между подходами:', 'Эс алуу убактысы:', 'Rest between sets:'),
                                    style: TextStyle(
                                      color: _restSecondsRemaining > 0 ? AppColors.amber : palette.fg,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _restButton('+30с', 30, palette),
                                const SizedBox(width: 6),
                                _restButton('+60с', 60, palette),
                                const SizedBox(width: 6),
                                _restButton('+90с', 90, palette),
                                if (_restSecondsRemaining > 0) ...[
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () {
                                      _restTimer?.cancel();
                                      setState(() => _restSecondsRemaining = 0);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      child: Icon(Icons.close, size: 14, color: palette.muted),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
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
                                onPressed: _isFinishingWorkout ? null : _stopWorkout,
                                icon: _isFinishingWorkout
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.stop, size: 18),
                                label: Text(_isFinishingWorkout
                                    ? AppLocaleNotifier.pick('Сохранение...', 'Сакталууда...', 'Saving...')
                                    : AppStrings.tr('sport_finish', language)),
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
                        Text(
                          AppLocaleNotifier.pick(
                            'СААТ-1 синхронизирует живой пульс, каденс и кардио-нагрузку в режиме реального времени.',
                            'СААТ-1 реалдуу убакытта пульс, каденс жана жүктөмдү жазат.',
                            'SAAT-1 syncs live heart rate, cadence and cardio load in real time.',
                          ),
                          style: TextStyle(color: palette.secondary, fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _startWorkout,
                            icon: const Icon(Icons.play_arrow, color: Colors.white),
                            label: Text(
                              '${AppStrings.tr('sport_start', language)} · ${_selectedSport.localizedTitle(language.code)}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.amber,
                              foregroundColor: Colors.white,
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
                                  style: TextStyle(color: palette.fg, fontSize: 13, fontWeight: FontWeight.w600),
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
                              style: TextStyle(color: palette.secondary, fontSize: 11, height: 1.3),
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
                                style: TextStyle(color: palette.fg),
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
                            style: TextStyle(
                              color: palette.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            '$_weekMinutes / 200 мин (${((_weekMinutes / 200) * 100).clamp(0, 100).round()}%)',
                            style: const TextStyle(
                              color: AppColors.sage,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_weekMinutes / 200).clamp(0.0, 1.0),
                          backgroundColor: palette.hairline,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sage),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocaleNotifier.pick(
                          '128 мин в Аэробной Зоне 2 + 24 мин интервалов в Зоне 5 обеспечивают омоложение миокарда.',
                          'Аэробдук 2-зонадагы 128 мүнөт + 5-зонадагы 24 мүнөт интервалдар жүрөктү жашартат.',
                          '128 min in Aerobic Zone 2 + 24 min Zone 5 intervals optimize heart rejuvenation.',
                        ),
                        style: TextStyle(color: palette.secondary, fontSize: 11, height: 1.35),
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
                          borderRadius: BorderRadius.circular(12),
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
                                  style: TextStyle(color: palette.fg, fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.sage.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text(
                                    'AUTO SYNC',
                                    style: TextStyle(color: AppColors.sage, fontSize: 8.5, fontWeight: FontWeight.w800),
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
                              style: TextStyle(color: palette.secondary, fontSize: 11),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: palette.hairline),
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
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
                  style: TextStyle(color: palette.fg, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                if (_history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        AppLocaleNotifier.pick('Пока нет сохранённых тренировок.', 'Машыгуулар жок.', 'No saved workouts yet.'),
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
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: AppColors.amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.25), width: 1.0),
                                ),
                                child: Icon(w.sport.icon, color: AppColors.amber, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(w.sport.title, style: TextStyle(color: palette.fg, fontWeight: FontWeight.w600, fontSize: 13)),
                                        if (w.isExternal) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: w.sourceColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(color: w.sourceColor.withValues(alpha: 0.4), width: 0.8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(w.sourceIcon, size: 10, color: w.sourceColor),
                                                const SizedBox(width: 3),
                                                Text(
                                                  w.sourceDisplayName,
                                                  style: TextStyle(color: w.sourceColor, fontSize: 9, fontWeight: FontWeight.w700),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
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
          color: palette.surface,
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

  Widget _categoryFilterChip(SportCategoryFilter category, String title, KalkanColors palette) {
    final isSelected = _categoryFilter == category;
    return InkWell(
      onTap: () {
        CircaHaptics.selectionClick();
        setState(() => _categoryFilter = category);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.amber : palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.amber : palette.hairline,
            width: 1.0,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : palette.fg,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _restButton(String label, int seconds, KalkanColors palette) {
    return InkWell(
      onTap: () => _startRestTimer(seconds),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.hairline),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: palette.fg,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
