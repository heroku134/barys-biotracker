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
  final HormonalCyclePhase? cyclePhase;
  final int? cycleDay;

  const UserProfile({
    this.id = 'circa_user_01',
    this.name = 'Алихан',
    this.email = 'alikhan@circa.health',
    this.heightCm = 178.0,
    this.weightKg = 74.5,
    this.birthYear = 1992,
    this.gender = Gender.male,
    this.stepGoal = 10000,
    this.calorieGoal = 650,
    this.sleepGoalHours = 8.0,
    this.is24HourFormat = true,
    this.isMetric = true,
    this.isAuthenticated = true,
    this.cyclePhase,
    this.cycleDay,
  });

  int get age => DateTime.now().year - birthYear;

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

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
    HormonalCyclePhase? cyclePhase,
    int? cycleDay,
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
      cyclePhase: cyclePhase ?? this.cyclePhase,
      cycleDay: cycleDay ?? this.cycleDay,
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
    'cyclePhase': cyclePhase?.name,
    'cycleDay': cycleDay,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? 'circa_user_01',
      name: json['name'] as String? ?? 'Алихан',
      email: json['email'] as String? ?? 'alikhan@circa.health',
      heightCm: (json['heightCm'] as num?)?.toDouble() ?? 178.0,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 74.5,
      birthYear: json['birthYear'] as int? ?? 1992,
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
      cyclePhase: json['cyclePhase'] != null
          ? HormonalCyclePhase.values.firstWhere(
              (p) => p.name == json['cyclePhase'],
              orElse: () => HormonalCyclePhase.follicular,
            )
          : null,
      cycleDay: json['cycleDay'] as int?,
    );
  }

  String serialize() => jsonEncode(toJson());

  static UserProfile deserialize(String str) =>
      UserProfile.fromJson(jsonDecode(str) as Map<String, dynamic>);
}
