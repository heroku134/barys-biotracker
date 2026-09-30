import 'dart:convert';

enum Gender { male, female, other }

enum HormonalCyclePhase {
  follicular('Фолликулярная фаза', 'Эстроген растет. ВСР и готовность к нагрузкам на пике.'),
  ovulatory('Овуляция', 'Кратковременный всплеск эстрогена. Высокая работоспособность.'),
  luteal('Лютеиновая фаза', 'Прогестерон повышен. Пульс покоя может вырасти на 2-4 уд/мин, ВСР ниже нормы на 10-15%. Это естественный физиологический процесс, а не перетренированность.'),
  menstrual('Менструальная фаза', 'Спад гормонов. Снизьте интенсивность, ориентируйтесь на мягкое кардио в Зоне 2.');

  final String title;
  final String description;

  const HormonalCyclePhase(this.title, this.description);
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final double heightCm;
  final double weightKg;
  final int birthYear;
  final Gender gender;
  final int stepGoal;
  final int calorieGoal;
  final double sleepGoalHours;
  final bool is24HourFormat;
  final bool isMetric;
  final bool isAuthenticated;
  final bool hasCompletedProfile;
  final HormonalCyclePhase? cyclePhase;
  final int? cycleDay;
  final int cycleLengthDays;
  final int periodDurationDays;
  final DateTime? lastPeriodStartDate;
  final String? avatarPath;
  final bool isPregnant;
  final DateTime? pregnancyDueDate;
  final DateTime? pregnancyLmpDate;

  const UserProfile({
    this.id = 'kalkan_user_01',
    this.name = '',
    this.email = '',
    this.heightCm = 175.0,
    this.weightKg = 72.0,
    this.birthYear = 1996,
    this.gender = Gender.male,
    this.stepGoal = 10000,
    this.calorieGoal = 650,
    this.sleepGoalHours = 8.0,
    this.is24HourFormat = true,
    this.isMetric = true,
    this.isAuthenticated = false,
    this.hasCompletedProfile = false,
    this.cyclePhase,
    this.cycleDay,
    this.cycleLengthDays = 28,
    this.periodDurationDays = 5,
    this.lastPeriodStartDate,
    this.avatarPath,
    this.isPregnant = false,
    this.pregnancyDueDate,
    this.pregnancyLmpDate,
  });

  int get age => (DateTime.now().year - birthYear).clamp(12, 100);

  int get maxHeartRate => (220 - age).clamp(140, 220);

  int getHeartRateZone(int currentBpm) {
    final maxHr = maxHeartRate;
    final pct = currentBpm / maxHr;
    if (pct < 0.60) return 0; // Зона 1: Восстановление (<60%)
    if (pct < 0.70) return 1; // Зона 2: Жиросжигание (60-70%)
    if (pct < 0.80) return 2; // Зона 3: Аэробная выносливость (70-80%)
    if (pct < 0.90) return 3; // Зона 4: Анаэробный порог (80-90%)
    return 4; // Зона 5: Пиковая нагрузка (>90%)
  }

  int calculateCaloriesBurned({required int durationSeconds, required int avgHr}) {
    if (durationSeconds <= 0) return 0;
    final minutes = durationSeconds / 60.0;
    final hr = avgHr > 40 ? avgHr : 115;
    final w = weightKg > 30 ? weightKg : 70.0;
    final a = age > 10 ? age : 25;

    // Формула Keytel et al. (2005) для расчёта расхода ккал по ЧСС, весу, возрасту и полу
    final double caloriesPerMin;
    if (gender == Gender.female) {
      caloriesPerMin = ((-20.4022 + (0.4472 * hr) - (0.1263 * w) + (0.074 * a)) / 4.184).clamp(3.0, 25.0);
    } else {
      caloriesPerMin = ((-55.0969 + (0.6309 * hr) + (0.1988 * w) + (0.2017 * a)) / 4.184).clamp(3.5, 30.0);
    }
    return (caloriesPerMin * minutes).round();
  }

  double get bmi {
    if (heightCm <= 50 || weightKg <= 10) return 22.0;
    final h = heightCm / 100.0;
    return weightKg / (h * h);
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    double? heightCm,
    double? weightKg,
    int? birthYear,
    Gender? gender,
    int? stepGoal,
    int? calorieGoal,
    double? sleepGoalHours,
    bool? is24HourFormat,
    bool? isMetric,
    bool? isAuthenticated,
    bool? hasCompletedProfile,
    HormonalCyclePhase? cyclePhase,
    int? cycleDay,
    int? cycleLengthDays,
    int? periodDurationDays,
    DateTime? lastPeriodStartDate,
    String? avatarPath,
    bool? isPregnant,
    DateTime? pregnancyDueDate,
    DateTime? pregnancyLmpDate,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      birthYear: birthYear ?? this.birthYear,
      gender: gender ?? this.gender,
      stepGoal: stepGoal ?? this.stepGoal,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      sleepGoalHours: sleepGoalHours ?? this.sleepGoalHours,
      is24HourFormat: is24HourFormat ?? this.is24HourFormat,
      isMetric: isMetric ?? this.isMetric,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      hasCompletedProfile: hasCompletedProfile ?? this.hasCompletedProfile,
      cyclePhase: cyclePhase ?? this.cyclePhase,
      cycleDay: cycleDay ?? this.cycleDay,
      cycleLengthDays: cycleLengthDays ?? this.cycleLengthDays,
      periodDurationDays: periodDurationDays ?? this.periodDurationDays,
      lastPeriodStartDate: lastPeriodStartDate ?? this.lastPeriodStartDate,
      avatarPath: avatarPath ?? this.avatarPath,
      isPregnant: isPregnant ?? this.isPregnant,
      pregnancyDueDate: pregnancyDueDate ?? this.pregnancyDueDate,
      pregnancyLmpDate: pregnancyLmpDate ?? this.pregnancyLmpDate,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'birthYear': birthYear,
    'gender': gender.name,
    'stepGoal': stepGoal,
    'calorieGoal': calorieGoal,
    'sleepGoalHours': sleepGoalHours,
    'is24HourFormat': is24HourFormat,
    'isMetric': isMetric,
    'isAuthenticated': isAuthenticated,
    'hasCompletedProfile': hasCompletedProfile,
    'cyclePhase': cyclePhase?.name,
    'cycleDay': cycleDay,
    'cycleLengthDays': cycleLengthDays,
    'periodDurationDays': periodDurationDays,
    'lastPeriodStartDate': lastPeriodStartDate?.toIso8601String(),
    'avatarPath': avatarPath,
    'isPregnant': isPregnant,
    'pregnancyDueDate': pregnancyDueDate?.toIso8601String(),
    'pregnancyLmpDate': pregnancyLmpDate?.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] as String? ?? '';
    final hasCompleted = json['hasCompletedProfile'] as bool? ??
        (rawName.isNotEmpty && rawName != 'Алихан' && json['heightCm'] != null);

    return UserProfile(
      id: json['id'] as String? ?? 'kalkan_user_01',
      name: rawName.isNotEmpty ? rawName : (hasCompleted ? '' : 'Гость'),
      email: json['email'] as String? ?? '',
      heightCm: (json['heightCm'] as num?)?.toDouble() ?? 175.0,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 72.0,
      birthYear: json['birthYear'] as int? ?? 1996,
      gender: Gender.values.firstWhere(
        (g) => g.name == json['gender'],
        orElse: () => Gender.male,
      ),
      stepGoal: json['stepGoal'] as int? ?? 10000,
      calorieGoal: json['calorieGoal'] as int? ?? 650,
      sleepGoalHours: (json['sleepGoalHours'] as num?)?.toDouble() ?? 8.0,
      is24HourFormat: json['is24HourFormat'] as bool? ?? true,
      isMetric: json['isMetric'] as bool? ?? true,
      isAuthenticated: json['isAuthenticated'] as bool? ?? true,
      hasCompletedProfile: hasCompleted,
      cyclePhase: json['cyclePhase'] != null
          ? HormonalCyclePhase.values.firstWhere(
              (p) => p.name == json['cyclePhase'],
              orElse: () => HormonalCyclePhase.follicular,
            )
          : null,
      cycleDay: json['cycleDay'] as int?,
      cycleLengthDays: json['cycleLengthDays'] as int? ?? 28,
      periodDurationDays: json['periodDurationDays'] as int? ?? 5,
      lastPeriodStartDate: json['lastPeriodStartDate'] != null
          ? DateTime.tryParse(json['lastPeriodStartDate'] as String)
          : null,
      avatarPath: json['avatarPath'] as String?,
      isPregnant: json['isPregnant'] as bool? ?? false,
      pregnancyDueDate: json['pregnancyDueDate'] != null ? DateTime.tryParse(json['pregnancyDueDate'] as String) : null,
      pregnancyLmpDate: json['pregnancyLmpDate'] != null ? DateTime.tryParse(json['pregnancyLmpDate'] as String) : null,
    );
  }

  String serialize() => jsonEncode(toJson());

  static UserProfile deserialize(String str) =>
      UserProfile.fromJson(jsonDecode(str) as Map<String, dynamic>);
}
