import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/intelligence/menstrual_cycle_engine.dart';
import '../../domain/models/partner_cycle_data.dart';
import '../../domain/models/user_profile.dart';
import '../services/cloud_sync_service.dart';

/// Репозиторий синхронизации цикла партнёрши (чтение, запись, реактивные обновления)
class PartnerCycleRepository {
  static const String _storageKey = 'circa_partner_cycle_data';

  static final ValueNotifier<PartnerCycleData> notifier = ValueNotifier<PartnerCycleData>(
    PartnerCycleData(lastSyncTime: DateTime.now()),
  );

  static bool isInitialized = false;

  /// Инициализация при запуске приложения
  static Future<PartnerCycleData> loadPartnerCycle() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final loaded = PartnerCycleData.deserialize(raw);

    final data = loaded ?? PartnerCycleData(lastSyncTime: DateTime.now());
    notifier.value = data;
    isInitialized = true;
    return data;
  }

  /// Сохранение данных цикла партнёрши
  static Future<void> savePartnerCycle(PartnerCycleData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, data.serialize());
    notifier.value = data;
    CloudSyncService.pushCycle(data);
  }

  /// Привязка партнера по инвайт-коду
  static Future<void> linkPartner({
    required String partnerCode,
    String? partnerName,
    int cycleDay = 14,
    int cycleLength = 28,
  }) async {
    if (partnerCode.trim().isEmpty) return;
    final phase = MenstrualCycleEngine.determinePhase(cycleDay, cycleLength: cycleLength);
    final tempDelta = MenstrualCycleEngine.expectedThermalDelta(cycleDay, cycleLength: cycleLength);

    final resolvedName = (partnerName != null && partnerName.trim().isNotEmpty)
        ? partnerName.trim()
        : 'Партнёр';

    final linkedData = PartnerCycleData(
      isLinked: true,
      partnerName: resolvedName,
      partnerCode: partnerCode.trim(),
      cycleDay: cycleDay,
      cycleLength: cycleLength,
      phase: phase,
      skinTempDeviation: tempDelta,
      energyScore: 4,
      mood: 'Спокойствие',
      flow: 'none',
      symptoms: const ['Энергичность', 'Ясность ума'],
      note: 'Синхронизировано по BLE 5.3 СААТ-1',
      lastSyncTime: DateTime.now(),
    );

    await savePartnerCycle(linkedData);
  }

  /// Отвязка партнёра
  static Future<void> unlinkPartner() async {
    final current = notifier.value;
    final unlinked = current.copyWith(
      isLinked: false,
      partnerName: '',
      partnerCode: '',
      lastSyncTime: DateTime.now(),
    );
    await savePartnerCycle(unlinked);
  }

  /// Автоматическая синхронизация биоритма девушки в общее хранилище партнера
  static Future<void> syncFromFemaleProfile(
    UserProfile profile, {
    int? currentCycleDay,
    int? energyScore,
    String? mood,
    String? flow,
    List<String>? symptoms,
    String? note,
    double? skinTempDeviation,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final day = currentCycleDay ??
        MenstrualCycleEngine.calculateCurrentCycleDay(
          profile.lastPeriodStartDate,
          cycleLength: profile.cycleLengthDays > 0 ? profile.cycleLengthDays : 28,
        );
    final len = profile.cycleLengthDays > 0 ? profile.cycleLengthDays : 28;
    final phase = MenstrualCycleEngine.determinePhase(day, cycleLength: len, periodDuration: profile.periodDurationDays);
    final temp = skinTempDeviation ?? MenstrualCycleEngine.expectedThermalDelta(day, cycleLength: len);

    final partnerCode = prefs.getString('cycle_partner_invite_code') ?? '';
    final partnerName = profile.name;

    final updated = notifier.value.copyWith(
      partnerName: partnerName,
      partnerCode: partnerCode,
      cycleDay: day,
      cycleLength: len,
      phase: phase,
      skinTempDeviation: temp,
      energyScore: energyScore ?? notifier.value.energyScore,
      mood: mood ?? notifier.value.mood,
      flow: flow ?? notifier.value.flow,
      symptoms: symptoms ?? notifier.value.symptoms,
      note: note ?? notifier.value.note,
      lastSyncTime: DateTime.now(),
    );

    await savePartnerCycle(updated);
  }
}
