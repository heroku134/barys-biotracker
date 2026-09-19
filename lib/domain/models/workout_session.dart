import 'package:flutter/material.dart';

enum SportType {
  runOutdoor('run_outdoor', 'Бег на улице', Icons.directions_run, true, false),
  runIndoor('run_indoor', 'Беговая дорожка', Icons.directions_walk, true, false),
  strength('strength', 'Силовая сессия', Icons.fitness_center, false, false),
  hiit('hiit', 'Интервалы HIIT', Icons.flash_on, false, false),
  cycling('cycling', 'Велоспорт', Icons.directions_bike, true, false),
  swimming('swimming', 'Плавание в бассейне', Icons.pool, false, true),
  yoga('yoga', 'Йога и стретчинг', Icons.self_improvement, false, false);

  final String id;
  final String title;
  final IconData icon;
  final bool hasDistance;
  final bool hasPoolLaps;

  const SportType(this.id, this.title, this.icon, this.hasDistance, this.hasPoolLaps);

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
        case SportType.runIndoor:
          return 'Чуркоо тренажеру';
        case SportType.strength:
          return 'Күч машыгуусу';
        case SportType.hiit:
          return 'Интервалдык HIIT';
        case SportType.cycling:
          return 'Велоспорт';
        case SportType.swimming:
          return 'Бассейнде сүзүү';
        case SportType.yoga:
          return 'Йога жана чоюлуу';
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
  });

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
  };

  factory CompletedWorkout.fromJson(Map<String, dynamic> json) {
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
    );
  }
}
