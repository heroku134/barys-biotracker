import 'package:flutter/material.dart';

enum SportType {
  runOutdoor('run_outdoor', 'Бег на улице', Icons.directions_run, true, false, true),
  cycling('cycling', 'Велоспорт', Icons.directions_bike, true, false, true),
  walkOutdoor('walk_outdoor', 'Ходьба на улице', Icons.directions_walk, true, false, true),
  runIndoor('run_indoor', 'Беговая дорожка', Icons.directions_run, true, false, false),
  strength('strength', 'Силовая тренировка', Icons.fitness_center, false, false, false),
  hiit('hiit', 'Интервалы HIIT', Icons.flash_on, false, false, false),
  combat('combat', 'Единоборства / Бокс', Icons.sports_mma, false, false, false),
  yoga('yoga', 'Йога и стретчинг', Icons.self_improvement, false, false, false),
  swimming('swimming', 'Плавание в бассейне', Icons.pool, false, true, false);

  final String id;
  final String title;
  final IconData icon;
  final bool hasDistance;
  final bool hasPoolLaps;
  final bool needsGps;

  const SportType(
    this.id,
    this.title,
    this.icon,
    this.hasDistance,
    this.hasPoolLaps,
    this.needsGps,
  );

  bool get isOutdoor => needsGps;
  bool get isIndoor => !needsGps;

  static SportType fromId(String id) {
    return SportType.values.firstWhere(
      (s) => s.id == id,
      orElse: () => SportType.runOutdoor,
    );
  }

  String localizedTitle([String? languageCode]) {
    if (languageCode == 'ky') {
      switch (this) {
        case SportType.runOutdoor:
          return 'Тышта чуркоо';
        case SportType.cycling:
          return 'Велоспорт';
        case SportType.walkOutdoor:
          return 'Тышта басуу';
        case SportType.runIndoor:
          return 'Чуркоо тренажеру';
        case SportType.strength:
          return 'Күч машыгуусу';
        case SportType.hiit:
          return 'Интервалдык HIIT';
        case SportType.combat:
          return 'Мушташ / Бокс';
        case SportType.yoga:
          return 'Йога жана чоюлуу';
        case SportType.swimming:
          return 'Бассейнде сүзүү';
      }
    }
    return title;
  }
}

class CompletedWorkout {
  final String id;
  final SportType sport;
  final DateTime startedAt;
  final int durationSeconds;
  final int calories;
  final double distanceKm;
  final int avgHr;
  final int maxHr;
  final double strain;
  final int xpEarned;
  final List<List<double>> routeCoordinates;
  final double avgPaceMinPerKm;
  final int steps;
  final int cadence;
  final List<int> hrZoneSeconds;
  final String? externalSource;
  final String? externalId;
  final String? sourceAppName;

  const CompletedWorkout({
    required this.id,
    required this.sport,
    required this.startedAt,
    required this.durationSeconds,
    required this.calories,
    required this.distanceKm,
    required this.avgHr,
    required this.maxHr,
    required this.strain,
    required this.xpEarned,
    this.routeCoordinates = const [],
    this.avgPaceMinPerKm = 0.0,
    this.steps = 0,
    this.cadence = 0,
    this.hrZoneSeconds = const [0, 0, 0, 0, 0],
    this.externalSource,
    this.externalId,
    this.sourceAppName,
  });

  bool get hasRoute => routeCoordinates.length >= 2;
  bool get isExternal => externalSource != null && externalSource!.isNotEmpty;

  String get sourceDisplayName {
    if (sourceAppName != null && sourceAppName!.isNotEmpty) return sourceAppName!;
    switch (externalSource) {
      case 'strava':
        return 'Strava';
      case 'garmin':
        return 'Garmin';
      case 'apple_health':
        return 'Apple Health';
      case 'health_connect':
        return 'Health Connect';
      case 'whoop':
        return 'Whoop';
      default:
        return 'Внешний трекер';
    }
  }

  Color get sourceColor {
    switch (externalSource) {
      case 'strava':
        return const Color(0xFFFC4C02);
      case 'garmin':
        return const Color(0xFF007CC3);
      case 'apple_health':
        return const Color(0xFFFF2D55);
      case 'health_connect':
        return const Color(0xFF34A853);
      default:
        return const Color(0xFFE5A93C);
    }
  }

  IconData get sourceIcon {
    switch (externalSource) {
      case 'strava':
        return Icons.navigation_outlined;
      case 'garmin':
        return Icons.watch_outlined;
      case 'apple_health':
        return Icons.favorite_outline;
      case 'health_connect':
        return Icons.sync;
      default:
        return Icons.cloud_sync_outlined;
    }
  }

  String get durationFormatted {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final remM = m % 60;
      return '$hч $remMм';
    }
    return '$mм ${s.toString().padLeft(2, '0')}с';
  }

  String get paceFormatted {
    if (avgPaceMinPerKm <= 0 || avgPaceMinPerKm > 60) {
      if (distanceKm > 0 && durationSeconds > 0) {
        final paceDec = (durationSeconds / 60.0) / distanceKm;
        var pm = paceDec.toInt();
        var ps = ((paceDec - pm) * 60).round();
        if (ps >= 60) { pm += 1; ps -= 60; }
        return "$pm'${ps.toString().padLeft(2, '0')}\" / км";
      }
      return "--'--\" / км";
    }
    var m = avgPaceMinPerKm.toInt();
    var s = ((avgPaceMinPerKm - m) * 60).round();
    if (s >= 60) { m += 1; s -= 60; }
    return "$m'${s.toString().padLeft(2, '0')}\" / км";
  }

  CompletedWorkout copyWith({
    String? id,
    SportType? sport,
    DateTime? startedAt,
    int? durationSeconds,
    int? calories,
    double? distanceKm,
    int? avgHr,
    int? maxHr,
    double? strain,
    int? xpEarned,
    List<List<double>>? routeCoordinates,
    double? avgPaceMinPerKm,
    int? steps,
    int? cadence,
    List<int>? hrZoneSeconds,
    String? externalSource,
    String? externalId,
    String? sourceAppName,
  }) {
    return CompletedWorkout(
      id: id ?? this.id,
      sport: sport ?? this.sport,
      startedAt: startedAt ?? this.startedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      calories: calories ?? this.calories,
      distanceKm: distanceKm ?? this.distanceKm,
      avgHr: avgHr ?? this.avgHr,
      maxHr: maxHr ?? this.maxHr,
      strain: strain ?? this.strain,
      xpEarned: xpEarned ?? this.xpEarned,
      routeCoordinates: routeCoordinates ?? this.routeCoordinates,
      avgPaceMinPerKm: avgPaceMinPerKm ?? this.avgPaceMinPerKm,
      steps: steps ?? this.steps,
      cadence: cadence ?? this.cadence,
      hrZoneSeconds: hrZoneSeconds ?? this.hrZoneSeconds,
      externalSource: externalSource ?? this.externalSource,
      externalId: externalId ?? this.externalId,
      sourceAppName: sourceAppName ?? this.sourceAppName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sportId': sport.id,
    'startedAt': startedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'calories': calories,
    'distanceKm': distanceKm,
    'avgHr': avgHr,
    'maxHr': maxHr,
    'strain': strain,
    'xpEarned': xpEarned,
    'routeCoordinates': routeCoordinates,
    'avgPaceMinPerKm': avgPaceMinPerKm,
    'steps': steps,
    'cadence': cadence,
    'hrZoneSeconds': hrZoneSeconds,
    'externalSource': externalSource,
    'externalId': externalId,
    'sourceAppName': sourceAppName,
  };

  factory CompletedWorkout.fromJson(Map<String, dynamic> json) {
    final rawCoords = json['routeCoordinates'] as List<dynamic>?;
    final List<List<double>> coords = [];
    if (rawCoords != null) {
      for (final pt in rawCoords) {
        if (pt is List && pt.length >= 2) {
          coords.add([(pt[0] as num).toDouble(), (pt[1] as num).toDouble()]);
        }
      }
    }
    final rawZones = json['hrZoneSeconds'] as List<dynamic>?;
    final List<int> zones = rawZones != null
        ? rawZones.map((e) => (e as num).toInt()).toList()
        : const [0, 0, 0, 0, 0];

    return CompletedWorkout(
      id: json['id'] as String,
      sport: SportType.fromId(json['sportId'] as String),
      startedAt: DateTime.parse(json['startedAt'] as String),
      durationSeconds: json['durationSeconds'] as int,
      calories: json['calories'] as int,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      avgHr: json['avgHr'] as int,
      maxHr: json['maxHr'] as int,
      strain: (json['strain'] as num).toDouble(),
      xpEarned: json['xpEarned'] as int,
      routeCoordinates: coords,
      avgPaceMinPerKm: (json['avgPaceMinPerKm'] as num?)?.toDouble() ?? 0.0,
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      cadence: (json['cadence'] as num?)?.toInt() ?? 0,
      hrZoneSeconds: zones,
      externalSource: json['externalSource'] as String?,
      externalId: json['externalId'] as String?,
      sourceAppName: json['sourceAppName'] as String?,
    );
  }
}
