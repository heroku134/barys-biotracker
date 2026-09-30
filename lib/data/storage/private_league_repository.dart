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
    final userTelemetry = telemetry ?? BleTelemetry.empty();
    final readiness = ReadinessEngine.calculate(userTelemetry, baseline: const PersonalBaseline());

    final userMember = _buildCurrentUserMember(
      telemetry: userTelemetry,
      profile: userProfile,
      readiness: readiness,
    );

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final savedLeague = PrivateLeague.deserialize(jsonStr);
        // Очищаем старые демо-профили (friend_dauren, friend_alia, friend_timur), сохраняя реальных участников
        final updatedMembers = savedLeague.members
            .where((m) =>
                m.id != 'friend_dauren' &&
                m.id != 'friend_alia' &&
                m.id != 'friend_timur')
            .map((m) {
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
      } catch (e) {
        // Если данные повреждены, продолжим с пустым кругом
      }
    }

    final league = PrivateLeague(
      id: 'league_kalkan_01',
      title: 'Круг доверия',
      inviteCode: 'KALKAN-${userProfile.name.hashCode.abs().toString().padLeft(4, '0').substring(0, 4)}',
      maxMembers: 5,
      members: [userMember],
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
