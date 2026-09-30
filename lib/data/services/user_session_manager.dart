import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/intelligence/baseline_calibration_manager.dart';
import '../../domain/models/user_profile.dart';
import '../storage/calibration_store.dart';
import '../storage/day_journal_repository.dart';
import '../storage/day_snapshot_repository.dart';
import '../storage/local_day_strain.dart';
import '../storage/partner_cycle_repository.dart';
import '../storage/pregnancy_log_repository.dart';
import '../storage/private_league_repository.dart';
import '../storage/user_profile_repository.dart';
import '../storage/workout_repository.dart';
import 'health_sync_service.dart';

/// Менеджер сессии пользователя: обеспечивает полную изоляцию данных между аккаунтами,
/// очистку кэшей при смене пользователя, регистрации и выходе (App Store 5.1.1 & Medical Privacy).
class UserSessionManager {
  /// Полная очистка локальных пользовательских данных с устройства
  static Future<void> clearLocalUserData() async {
    debugPrint('UserSessionManager: Clearing all local user data for clean account state');

    // 1. Тренировки (включая сторонние импорты Strava/Garmin)
    await WorkoutRepository.clearWorkouts();

    // 2. Кэш синхронизации здоровья
    await HealthSyncService.clearSyncData();

    // 3. Снимки дней и суточный Strain
    await DaySnapshotRepository.clear();
    LocalDayStrain.reset();

    // 4. Калибровка бейзлайна СААТ-1
    await BaselineCalibrationManager.resetCalibration();
    await CalibrationStore.reset();

    // 5. Дневник самочувствия и заметки
    await DayJournalRepository.clear();

    // 6. Партнерский цикл и беременность
    await PartnerCycleRepository.clear();
    await PregnancyLogRepository.clear();

    // 7. Круг друзей (приватная лига)
    await PrivateLeagueRepository.resetToDefaultLeague();

    // 8. Маскот Барыс (уровень, XP, квесты)
    await AvatarManager.reset();

    // 9. Очистка ключей SharedPreferences, специфичных для пользователя
    try {
      final prefs = await SharedPreferences.getInstance();
      final keysToRemove = <String>[];
      for (final k in prefs.getKeys()) {
        if (k.startsWith('cycle_log_') ||
            k.startsWith('cycle_flow_') ||
            k.startsWith('cycle_energy_') ||
            k.startsWith('cycle_cramps_') ||
            k.startsWith('stress_slot_tag_') ||
            k.startsWith('kalkan_reminder_') ||
            k.startsWith('kalkan_preg_') ||
            k.startsWith('kalkan_daily_photo_') ||
            k == 'kalkan_cycle_partner_invite_code_v1') {
          keysToRemove.add(k);
        }
      }
      for (final k in keysToRemove) {
        await prefs.remove(k);
      }
    } catch (e) {
      debugPrint('UserSessionManager clear prefs error: $e');
    }

    // 10. Сброс состояния профиля
    UserProfileRepository.profileNotifier.value = const UserProfile(isAuthenticated: false);
  }
}
