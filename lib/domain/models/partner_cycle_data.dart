import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'user_profile.dart';

/// Модель данных биоритма партнёрши для синхронизации и отображения на главном экране
class PartnerCycleData {
  final bool isLinked;
  final String partnerName;
  final String partnerCode;
  final int cycleDay;
  final int cycleLength;
  final HormonalCyclePhase phase;
  final double skinTempDeviation;
  final int energyScore; // 1..5
  final String mood;
  final String flow; // 'none', 'light', 'medium', 'heavy'
  final List<String> symptoms;
  final String note;
  final DateTime lastSyncTime;

  const PartnerCycleData({
    this.isLinked = false,
    this.partnerName = 'Айпери',
    this.partnerCode = 'KLK-CYC-7482',
    this.cycleDay = 14,
    this.cycleLength = 28,
    this.phase = HormonalCyclePhase.ovulatory,
    this.skinTempDeviation = 0.32,
    this.energyScore = 4,
    this.mood = 'Спокойствие',
    this.flow = 'none',
    this.symptoms = const ['Энергичность', 'Ясность ума'],
    this.note = '',
    required this.lastSyncTime,
  });

  Color get phaseColor {
    switch (phase) {
      case HormonalCyclePhase.menstrual:
        return AppColors.rose;
      case HormonalCyclePhase.follicular:
        return AppColors.sage;
      case HormonalCyclePhase.ovulatory:
        return AppColors.amber;
      case HormonalCyclePhase.luteal:
        return const Color(0xFFA685B8);
    }
  }

  String get phaseTitle {
    switch (phase) {
      case HormonalCyclePhase.menstrual:
        return 'Менструация';
      case HormonalCyclePhase.follicular:
        return 'Фолликулярная';
      case HormonalCyclePhase.ovulatory:
        return 'Овуляция';
      case HormonalCyclePhase.luteal:
        return 'Лютеиновая';
    }
  }

  String get energyLabel {
    if (energyScore >= 4) return 'Высокий';
    if (energyScore == 3) return 'Оптимальный';
    return 'Сниженный';
  }

  String get energyEmoji => energyLabel;

  int get currentCycleDay => cycleDay;

  /// Эмпатичные и научно обоснованные рекомендации для партнера на сегодня
  String get partnerGuidance {
    switch (phase) {
      case HormonalCyclePhase.ovulatory:
        return 'Пик энергии, выносливости и настроения. Идеальное время для совместных тренировок, долгих прогулок и активного отдыха.';
      case HormonalCyclePhase.luteal:
        return 'Уровень прогестерона повышен, организму нужно больше покоя и тепла. Проявите заботу, помогите разгрузить домашние дела и окружите уютом.';
      case HormonalCyclePhase.menstrual:
        return 'Период восстановления и спада сил. Снизьте требования к физической активности, приготовьте горячий чай и дайте больше времени на сон.';
      case HormonalCyclePhase.follicular:
        return 'Эстроген плавно растет, силы возвращаются. Отличный период для новых совместных начинаний, планирования и вдохновения.';
    }
  }

  String get partnerAdvice => partnerGuidance;

  PartnerCycleData copyWith({
    bool? isLinked,
    String? partnerName,
    String? partnerCode,
    int? cycleDay,
    int? cycleLength,
    HormonalCyclePhase? phase,
    double? skinTempDeviation,
    int? energyScore,
    String? mood,
    String? flow,
    List<String>? symptoms,
    String? note,
    DateTime? lastSyncTime,
  }) {
    return PartnerCycleData(
      isLinked: isLinked ?? this.isLinked,
      partnerName: partnerName ?? this.partnerName,
      partnerCode: partnerCode ?? this.partnerCode,
      cycleDay: cycleDay ?? this.cycleDay,
      cycleLength: cycleLength ?? this.cycleLength,
      phase: phase ?? this.phase,
      skinTempDeviation: skinTempDeviation ?? this.skinTempDeviation,
      energyScore: energyScore ?? this.energyScore,
      mood: mood ?? this.mood,
      flow: flow ?? this.flow,
      symptoms: symptoms ?? this.symptoms,
      note: note ?? this.note,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isLinked': isLinked,
      'partnerName': partnerName,
      'partnerCode': partnerCode,
      'cycleDay': cycleDay,
      'cycleLength': cycleLength,
      'phase': phase.name,
      'skinTempDeviation': skinTempDeviation,
      'energyScore': energyScore,
      'mood': mood,
      'flow': flow,
      'symptoms': symptoms,
      'note': note,
      'lastSyncTime': lastSyncTime.toIso8601String(),
    };
  }

  factory PartnerCycleData.fromJson(Map<String, dynamic> map) {
    HormonalCyclePhase parsedPhase = HormonalCyclePhase.ovulatory;
    try {
      parsedPhase = HormonalCyclePhase.values.byName(map['phase'] ?? 'ovulatory');
    } catch (_) {}

    return PartnerCycleData(
      isLinked: map['isLinked'] ?? false,
      partnerName: map['partnerName'] ?? 'Айпери',
      partnerCode: map['partnerCode'] ?? 'KLK-CYC-7482',
      cycleDay: map['cycleDay'] ?? 14,
      cycleLength: map['cycleLength'] ?? 28,
      phase: parsedPhase,
      skinTempDeviation: (map['skinTempDeviation'] as num?)?.toDouble() ?? 0.32,
      energyScore: map['energyScore'] ?? 4,
      mood: map['mood'] ?? 'Спокойствие',
      flow: map['flow'] ?? 'none',
      symptoms: List<String>.from(map['symptoms'] ?? []),
      note: map['note'] ?? '',
      lastSyncTime: map['lastSyncTime'] != null
          ? DateTime.tryParse(map['lastSyncTime']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String serialize() => jsonEncode(toJson());

  static PartnerCycleData? deserialize(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PartnerCycleData.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}
