import 'package:shared_preferences/shared_preferences.dart';
import '../../core/circa_haptics.dart';
import '../../domain/intelligence/readiness_engine.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/private_league.dart';
import '../../domain/models/readiness.dart';
import '../../domain/models/telemetry.dart';
import '../../domain/models/user_profile.dart';
import 'user_profile_repository.dart';

class PrivateLeagueRepository {
  static const String _keyLeague = 'circa_private_league_v1';

  static List<FriendMember> _buildDefaultFriends() {
    return [
      const FriendMember(
        id: 'friend_dauren',
        name: 'Даурен С.',
        city: 'Алматы',
        avatarInitials: 'ДС',
        rankTitle: '',
        level: 4,
        recoveryScore: 86,
        recoveryZone: RecoveryZone.optimal,
        currentDayStrain: 14.2,
        sleepHours: 7.8,
        sleepPerformance: 94,
        hrv: 68.0,
        restingHeartRate: 48,
        lastSyncText: 'Live',
        statusQuote: '«Закрыл 15 км по горному трейлу Медеу»',
      ),
      const FriendMember(
        id: 'friend_alia',
        name: 'Алия М.',
        city: 'Алматы',
        avatarInitials: 'АМ',
        rankTitle: '',
        level: 3,
        recoveryScore: 68,
        recoveryZone: RecoveryZone.moderate,
        currentDayStrain: 9.5,
        sleepHours: 6.7,
        sleepPerformance: 82,
        hrv: 52.0,
        restingHeartRate: 54,
        lastSyncText: '18 мин назад',
        statusQuote: '«День активного восстановления и растяжки»',
      ),
      const FriendMember(
        id: 'friend_timur',
        name: 'Тимур К.',
        city: 'Астана',
        avatarInitials: 'ТК',
        rankTitle: '',
        level: 2,
        recoveryScore: 92,
        recoveryZone: RecoveryZone.optimal,
        currentDayStrain: 12.0,
        sleepHours: 8.2,
        sleepPerformance: 96,
        hrv: 74.0,
        restingHeartRate: 46,
        lastSyncText: '45 мин назад',
        statusQuote: '«Пиковая форма, готов к вечернему заезду»',
      ),
    ];
  }

  static FriendMember _buildCurrentUserMember({
    required BleTelemetry telemetry,
    required UserProfile profile,
    required ReadinessResult readiness,
  }) {
    final initials = profile.name.trim().isNotEmpty
        ? profile.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join()
        : 'ВЫ';

    return FriendMember(
      id: 'current_user_me',
      name: profile.name.isNotEmpty ? '${profile.name} (Вы)' : 'Вы',
      city: 'Алматы',
      avatarInitials: initials.isNotEmpty ? initials : 'ВЫ',
      rankTitle: '',
      level: 1,
      recoveryScore: readiness.score,
      recoveryZone: readiness.zone,
      currentDayStrain: telemetry.currentDayStrain,
      sleepHours: telemetry.sleepMinutes / 60.0,
      sleepPerformance: (telemetry.sleepEfficiency * 100).round(),
      hrv: telemetry.hrv,
      restingHeartRate: telemetry.restingHeartRate,
      lastSyncText: 'Live',
      statusQuote: '«В синхроне с датчиком СААТ-1»',
      isCurrentUser: true,
    );
  }

  static Future<PrivateLeague> loadLeague({
    BleTelemetry? telemetry,
    UserProfile? profile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyLeague);

    final userProfile = profile ?? await UserProfileRepository.loadProfile();
    final userTelemetry = telemetry ?? BleTelemetry(
      heartRate: 68,
      hrv: 62.0,
      restingHeartRate: 52,
      respiratoryRate: 14.1,
      skinTempDeviation: 0.1,
      sleepMinutes: 460,
      timeInBedMinutes: 500,
      sleepEfficiency: 0.92,
      sleepConsistency: 0.88,
      restorativeSleepRatio: 0.75,
      currentDayStrain: 11.4,
      zoneMinutes: const [40, 30, 20, 10, 5],
      timestamp: DateTime.now(),
    );
    final readiness = ReadinessEngine.calculate(userTelemetry, baseline: const PersonalBaseline());

    final userMember = _buildCurrentUserMember(
      telemetry: userTelemetry,
      profile: userProfile,
      readiness: readiness,
    );

    if (jsonStr != null) {
      try {
        final savedLeague = PrivateLeague.deserialize(jsonStr);
        // Обновляем метрики текущего пользователя в списке
        final updatedMembers = savedLeague.members.map((m) {
          if (m.isCurrentUser) return userMember;
          return m;
        }).toList();

        // Если текущего пользователя почему-то нет в списке, добавляем его в начало
        if (!updatedMembers.any((m) => m.isCurrentUser)) {
          updatedMembers.insert(0, userMember);
        }

        return PrivateLeague(
          id: savedLeague.id,
          title: savedLeague.title.replaceAll('CIRCA', 'KALKAN'),
          inviteCode: savedLeague.inviteCode.replaceAll('CIRCA', 'KALKAN'),
          maxMembers: savedLeague.maxMembers,
          members: updatedMembers,
        );
      } catch (_) {}
    }

    // Дефолтная приватная лига (3 друга + текущий пользователь = 4/5)
    final initialMembers = [userMember, ..._buildDefaultFriends()];
    final league = PrivateLeague(
      id: 'league_atelier_01',
      title: 'КРУГ БАТЫРОВ · ALMATY ATELIER',
      inviteCode: 'KALKAN-BATYR-04',
      maxMembers: 5,
      members: initialMembers,
    );
    await saveLeague(league);
    return league;
  }

  static Future<void> saveLeague(PrivateLeague league) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLeague, league.serialize());
  }

  static Future<bool> addFriend({
    required String name,
    String? city,
    String? inviteCode,
  }) async {
    final league = await loadLeague();
    if (league.isFull) {
      return false; // Превышен лимит 5 участников
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return false;

    final initials = trimmedName.split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join();

    final newFriend = FriendMember(
      id: 'friend_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedName,
      city: city ?? 'Алматы',
      avatarInitials: initials.isNotEmpty ? initials : 'АТ',
      rankTitle: '',
      level: 2,
      recoveryScore: 78,
      recoveryZone: RecoveryZone.optimal,
      currentDayStrain: 8.5,
      sleepHours: 7.4,
      sleepPerformance: 88,
      hrv: 58.0,
      restingHeartRate: 50,
      lastSyncText: 'Только что',
      statusQuote: '«Присоединился к закрытому кругу»',
    );

    final updatedMembers = [...league.members, newFriend];
    final updatedLeague = PrivateLeague(
      id: league.id,
      title: league.title,
      inviteCode: league.inviteCode,
      maxMembers: league.maxMembers,
      members: updatedMembers,
    );

    await saveLeague(updatedLeague);
    CircaHaptics.questCompleted();
    return true;
  }

  static Future<void> removeFriend(String memberId) async {
    final league = await loadLeague();
    final updatedMembers = league.members.where((m) => m.id != memberId || m.isCurrentUser).toList();
    final updatedLeague = PrivateLeague(
      id: league.id,
      title: league.title,
      inviteCode: league.inviteCode,
      maxMembers: league.maxMembers,
      members: updatedMembers,
    );
    await saveLeague(updatedLeague);
  }

  static Future<void> sendImpulse(String friendId) async {
    CircaHaptics.questCompleted();
  }

  static Future<void> resetToDefaultLeague() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLeague);
  }
}
