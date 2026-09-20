import 'dart:convert';
import 'readiness.dart';

/// Модель участника закрытого круга / приватной лиги (3–5 близких друзей)
class FriendMember {
  final String id;
  final String name;
  final String city;
  final String avatarInitials;
  final String rankTitle;
  final int level;
  final int recoveryScore;
  final RecoveryZone recoveryZone;
  final double currentDayStrain;
  final double sleepHours;
  final int sleepPerformance;
  final double hrv;
  final int restingHeartRate;
  final String lastSyncText;
  final String statusQuote;
  final bool isCurrentUser;

  const FriendMember({
    required this.id,
    required this.name,
    required this.city,
    required this.avatarInitials,
    required this.rankTitle,
    required this.level,
    required this.recoveryScore,
    required this.recoveryZone,
    required this.currentDayStrain,
    required this.sleepHours,
    required this.sleepPerformance,
    required this.hrv,
    required this.restingHeartRate,
    required this.lastSyncText,
    required this.statusQuote,
    this.isCurrentUser = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'avatarInitials': avatarInitials,
      'rankTitle': rankTitle,
      'level': level,
      'recoveryScore': recoveryScore,
      'recoveryZone': recoveryZone.name,
      'currentDayStrain': currentDayStrain,
      'sleepHours': sleepHours,
      'sleepPerformance': sleepPerformance,
      'hrv': hrv,
      'restingHeartRate': restingHeartRate,
      'lastSyncText': lastSyncText,
      'statusQuote': statusQuote,
      'isCurrentUser': isCurrentUser,
    };
  }

  factory FriendMember.fromMap(Map<String, dynamic> map) {
    return FriendMember(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Атлет KALKAN',
      city: map['city'] as String? ?? 'Бишкек',
      avatarInitials: map['avatarInitials'] as String? ?? 'KS',
      rankTitle: map['rankTitle'] as String? ?? 'БАТЫР',
      level: map['level'] as int? ?? 1,
      recoveryScore: map['recoveryScore'] as int? ?? 75,
      recoveryZone: RecoveryZone.values.firstWhere(
        (z) => z.name == map['recoveryZone'],
        orElse: () => RecoveryZone.optimal,
      ),
      currentDayStrain: (map['currentDayStrain'] as num?)?.toDouble() ?? 10.0,
      sleepHours: (map['sleepHours'] as num?)?.toDouble() ?? 7.5,
      sleepPerformance: map['sleepPerformance'] as int? ?? 85,
      hrv: (map['hrv'] as num?)?.toDouble() ?? 60.0,
      restingHeartRate: map['restingHeartRate'] as int? ?? 52,
      lastSyncText: map['lastSyncText'] as String? ?? 'Live',
      statusQuote: map['statusQuote'] as String? ?? 'В синхроне с телом',
      isCurrentUser: map['isCurrentUser'] as bool? ?? false,
    );
  }
}

/// Модель приватной лиги KALKAN на 3–5 друзей (Dunbar Close Circle)
class PrivateLeague {
  final String id;
  final String title;
  final String inviteCode;
  final int maxMembers;
  final List<FriendMember> members;

  const PrivateLeague({
    required this.id,
    required this.title,
    required this.inviteCode,
    this.maxMembers = 5,
    required this.members,
  });

  bool get isFull => members.length >= maxMembers;
  int get availableSlots => (maxMembers - members.length).clamp(0, maxMembers);

  double get averageRecoveryScore {
    if (members.isEmpty) return 0.0;
    final total = members.fold<int>(0, (sum, m) => sum + m.recoveryScore);
    return total / members.length;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'inviteCode': inviteCode,
      'maxMembers': maxMembers,
      'members': members.map((m) => m.toMap()).toList(),
    };
  }

  factory PrivateLeague.fromMap(Map<String, dynamic> map) {
    final list = (map['members'] as List<dynamic>?) ?? [];
    return PrivateLeague(
      id: map['id'] as String? ?? 'league_inner_circle',
      title: map['title'] as String? ?? 'КРУГ БАТЫРОВ · ALMATY ATELIER',
      inviteCode: map['inviteCode'] as String? ?? 'KALKAN-BATYR-04',
      maxMembers: map['maxMembers'] as int? ?? 5,
      members: list.map((item) => FriendMember.fromMap(item as Map<String, dynamic>)).toList(),
    );
  }

  String serialize() => jsonEncode(toMap());

  factory PrivateLeague.deserialize(String jsonStr) {
    return PrivateLeague.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
  }
}
