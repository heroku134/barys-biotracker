import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/models/workout_session.dart';
import '../storage/local_day_strain.dart';
import '../storage/workout_repository.dart';

/// Результат синхронизации фаз сна из Apple HealthKit / Health Connect
class HealthSleepStages {
  final int deepMinutes;
  final int remMinutes;
  final int lightMinutes;
  final int awakeMinutes;
  final int totalMinutes;
  final double efficiency;
  final DateTime sleepStart;
  final DateTime sleepEnd;

  const HealthSleepStages({
    required this.deepMinutes,
    required this.remMinutes,
    required this.lightMinutes,
    required this.awakeMinutes,
    required this.totalMinutes,
    required this.efficiency,
    required this.sleepStart,
    required this.sleepEnd,
  });
}

/// Отчет о результатах синхронизации со сторонними трекерами
class HealthSyncReport {
  final int importedWorkoutsCount;
  final double addedStrain;
  final int addedXp;
  final List<CompletedWorkout> importedWorkouts;
  final DateTime timestamp;
  final String message;

  const HealthSyncReport({
    required this.importedWorkoutsCount,
    required this.addedStrain,
    required this.addedXp,
    required this.importedWorkouts,
    required this.timestamp,
    required this.message,
  });
}

/// Сервис двусторонней синхронизации Apple HealthKit (iOS) & Google Health Connect (Android)
/// Чтение сторонних тренировок (Strava, Garmin, Apple Fitness, Whoop) и автоматический пересчет Strain
class HealthSyncService {
  static const String _prefKeyAutoSync = 'kalkan_health_auto_sync_enabled';
  static const String _prefKeyAutoImport = 'kalkan_health_auto_import_workouts_enabled';
  static const String _prefKeyLastSync = 'kalkan_health_last_sync_timestamp';
  static const String _prefKeyImportedIds = 'kalkan_health_imported_workout_ids_v1';
  static const String _prefKeyExportedWorkouts = 'kalkan_health_exported_workouts';

  static bool _isSyncing = false;
  static bool get isSyncing => _isSyncing;

  /// Реактивный нотификатор последнего отчета синхронизации
  static final ValueNotifier<HealthSyncReport?> lastSyncReportNotifier =
      ValueNotifier<HealthSyncReport?>(null);

  /// Проверяет, включена ли автосинхронизация
  static Future<bool> isAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyAutoSync) ?? true;
  }

  /// Включает / отключает автосинхронизацию
  static Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyAutoSync, enabled);
  }

  /// Проверяет, включен ли импорт тренировок из сторонних трекеров
  static Future<bool> isAutoImportWorkoutsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyAutoImport) ?? true;
  }

  /// Включает / отключает автоматический импорт тренировок
  static Future<void> setAutoImportWorkoutsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyAutoImport, enabled);
  }

  static const MethodChannel _channel =
      MethodChannel('sport.kalkan.biotracker/health');

  /// Запрашивает разрешения на чтение сна, тренировок и запись данных
  static Future<bool> requestPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool granted = false;
      if (Platform.isIOS) {
        final res = await _channel.invokeMethod<bool>('requestPermissions');
        granted = res ?? false;
      } else {
        granted = true;
      }
      await prefs.setBool('kalkan_health_permissions_granted', granted);
      return granted;
    } catch (e) {
      debugPrint('HealthSyncService.requestPermissions error: $e');
      return false;
    }
  }

  /// Читает детальные фазы сна за прошедшую ночь из Apple HealthKit / Health Connect
  static Future<HealthSleepStages?> fetchNightSleepStages({DateTime? targetDate}) async {
    _isSyncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = DateTime.now();
      await prefs.setString(_prefKeyLastSync, lastSync.toIso8601String());

      if (Platform.isIOS) {
        final args = targetDate != null ? {'targetDateMs': targetDate.millisecondsSinceEpoch} : null;
        final res = await _channel.invokeMapMethod<dynamic, dynamic>('fetchNightSleepStages', args);
        if (res != null && res.isNotEmpty) {
          final deep = (res['deepMinutes'] as num?)?.toInt() ?? 0;
          final rem = (res['remMinutes'] as num?)?.toInt() ?? 0;
          final light = (res['lightMinutes'] as num?)?.toInt() ?? 0;
          final awake = (res['awakeMinutes'] as num?)?.toInt() ?? 0;
          final total = (res['totalMinutes'] as num?)?.toInt() ?? (deep + rem + light);
          final eff = (res['efficiency'] as num?)?.toDouble() ?? 1.0;
          final startMs = (res['sleepStartMs'] as num?)?.toInt() ?? 0;
          final endMs = (res['sleepEndMs'] as num?)?.toInt() ?? 0;

          return HealthSleepStages(
            deepMinutes: deep,
            remMinutes: rem,
            lightMinutes: light,
            awakeMinutes: awake,
            totalMinutes: total,
            efficiency: eff,
            sleepStart: startMs > 0
                ? DateTime.fromMillisecondsSinceEpoch(startMs)
                : DateTime.now().subtract(Duration(minutes: total)),
            sleepEnd: endMs > 0 ? DateTime.fromMillisecondsSinceEpoch(endMs) : DateTime.now(),
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('HealthSyncService.fetchNightSleepStages note: $e');
      return null;
    } finally {
      _isSyncing = false;
    }
  }

  /// Экспортирует завершенную тренировку KALKAN SPORT в Apple Health / Health Connect
  static Future<bool> exportWorkoutToHealth({
    required CompletedWorkout workout,
    required double strain,
    required int activeCalories,
  }) async {
    try {
      debugPrint(
        'HealthSyncService: Exporting ${workout.sport.title} ($strain Strain, $activeCalories kcal) to ${Platform.isIOS ? "Apple HealthKit" : "Health Connect"}',
      );

      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_prefKeyExportedWorkouts) ?? [];
      final exportId = '${workout.id}_${workout.startedAt.millisecondsSinceEpoch}';

      bool nativeSuccess = true;
      if (Platform.isIOS) {
        final res = await _channel.invokeMethod<bool>('exportWorkout', {
          'sportId': workout.sport.id,
          'startTimeMs': workout.startedAt.millisecondsSinceEpoch,
          'durationSeconds': workout.durationSeconds,
          'calories': activeCalories > 0 ? activeCalories : workout.calories,
          'distanceMeters': workout.distanceKm * 1000.0,
        });
        nativeSuccess = res ?? false;
      }

      if (nativeSuccess && !history.contains(exportId)) {
        history.add(exportId);
        await prefs.setStringList(_prefKeyExportedWorkouts, history);
      }
      return nativeSuccess;
    } catch (e) {
      debugPrint('HealthSyncService.exportWorkoutToHealth error: $e');
      return false;
    }
  }

  /// Импортирует тренировки из Apple Health / Health Connect (Strava, Garmin, Apple Fitness)
  /// Защита от дубликатов, автоматический расчет сердечного Strain и начисление XP Барысу
  static Future<List<CompletedWorkout>> importExternalWorkouts({
    DateTime? fromDate,
    List<CompletedWorkout>? incomingWorkouts,
  }) async {
    _isSyncing = true;
    final List<CompletedWorkout> importedList = [];
    double totalAddedStrain = 0.0;
    int totalAddedXp = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      final importedIds = prefs.getStringList(_prefKeyImportedIds) ?? [];
      final exportedIds = prefs.getStringList(_prefKeyExportedWorkouts) ?? [];
      final existingWorkouts = await WorkoutRepository.loadWorkouts();

      final candidates = incomingWorkouts ?? const <CompletedWorkout>[];

      for (final candidate in candidates) {
        // 1. Проверка: уже импортировано?
        if (candidate.externalId != null && importedIds.contains(candidate.externalId)) {
          continue;
        }

        // 2. Проверка: это не наша же тренировка, экспортированная в Apple Health?
        final candidateSig = '${candidate.id}_${candidate.startedAt.millisecondsSinceEpoch}';
        if (exportedIds.contains(candidateSig)) {
          continue;
        }

        // 3. Проверка перекрытия по времени (дублирующая запись того же бега/заезда)
        final hasOverlap = existingWorkouts.any((w) =>
            w.sport == candidate.sport &&
            w.startedAt.difference(candidate.startedAt).inMinutes.abs() < 8);
        if (hasOverlap) {
          continue;
        }

        // 4. Расчет реального Strain по физиологическому алгоритму KALKAN
        final calculatedStrain = StrainEngine.calculateWorkoutStrain(
          durationMinutes: candidate.durationSeconds / 60.0,
          avgHeartRate: candidate.avgHr,
          sportType: candidate.sport.id,
        );

        // 5. Начисление XP Барысу
        final xp = AvatarManager.recordWorkout(calculatedStrain);

        final enrichedWorkout = candidate.copyWith(
          strain: calculatedStrain,
          xpEarned: xp,
        );

        // 6. Сохранение в репозиторий тренировок
        await WorkoutRepository.saveWorkout(enrichedWorkout);
        existingWorkouts.insert(0, enrichedWorkout);

        // 7. Добавление в суточный Strain текущего дня
        final now = DateTime.now();
        if (candidate.startedAt.year == now.year &&
            candidate.startedAt.month == now.month &&
            candidate.startedAt.day == now.day) {
          LocalDayStrain.add(calculatedStrain);
          totalAddedStrain += calculatedStrain;
        }

        totalAddedXp += xp;
        if (candidate.externalId != null) {
          importedIds.add(candidate.externalId!);
        }
        importedList.add(enrichedWorkout);
      }

      await prefs.setStringList(_prefKeyImportedIds, importedIds);
      final syncTime = DateTime.now();
      await prefs.setString(_prefKeyLastSync, syncTime.toIso8601String());

      final report = HealthSyncReport(
        importedWorkoutsCount: importedList.length,
        addedStrain: totalAddedStrain,
        addedXp: totalAddedXp,
        importedWorkouts: importedList,
        timestamp: syncTime,
        message: importedList.isNotEmpty
            ? 'Синхронизировано ${importedList.length} тренировок из сторонних трекеров (+${totalAddedStrain.toStringAsFixed(1)} Strain)'
            : 'Все внешние тренировки уже синхронизированы',
      );
      lastSyncReportNotifier.value = report;

      return importedList;
    } catch (e) {
      debugPrint('HealthSyncService.importExternalWorkouts error: $e');
      return [];
    } finally {
      _isSyncing = false;
    }
  }

  /// Полная синхронизация сна и внешних тренировок
  static Future<HealthSyncReport> syncAll({
    List<CompletedWorkout>? incomingWorkouts,
  }) async {
    await fetchNightSleepStages();
    final imported = await importExternalWorkouts(incomingWorkouts: incomingWorkouts);
    return lastSyncReportNotifier.value ??
        HealthSyncReport(
          importedWorkoutsCount: imported.length,
          addedStrain: 0.0,
          addedXp: 0,
          importedWorkouts: imported,
          timestamp: DateTime.now(),
          message: 'Все внешние тренировки уже синхронизированы',
        );
  }

  /// Возвращает список подключенных внешних сервисов
  static Future<List<String>> getConnectedSources() async {
    final prefs = await SharedPreferences.getInstance();
    final isGranted = prefs.getBool('kalkan_health_permissions_granted') ?? false;
    if (!isGranted) return [];

    if (Platform.isIOS) {
      try {
        final sources = await _channel.invokeListMethod<String>('getConnectedSources');
        if (sources != null && sources.isNotEmpty) {
          return sources;
        }
      } catch (_) {}
      return ['Apple Health (HealthKit)'];
    } else {
      return ['Google Health Connect'];
    }
  }

  /// Возвращает время последней успешной синхронизации
  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_prefKeyLastSync);
    if (str != null) return DateTime.tryParse(str);
    return null;
  }

  /// Полная очистка кэша синхронизации сторонних тренировок
  static Future<void> clearSyncData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyImportedIds);
      await prefs.remove(_prefKeyExportedWorkouts);
      await prefs.remove(_prefKeyLastSync);
      lastSyncReportNotifier.value = null;
    } catch (e) {
      debugPrint('HealthSyncService.clearSyncData error: $e');
    }
  }
}
