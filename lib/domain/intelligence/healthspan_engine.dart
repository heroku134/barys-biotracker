class HealthspanResult {
  final int chronologicalAge;
  final double circaBiologicalAge;
  final double ageDeltaYears; // -4.6 (моложе)
  final double estimatedVo2Max; // мл/кг/мин
  final double rhrSixMonthTrend; // -3.2 уд/мин
  final int weeklyZone2Minutes;
  final int weeklyZone5Minutes;
  final double sleepConsistencyPercent;
  final String headline;
  final String physiologicalDetails;

  const HealthspanResult({
    required this.chronologicalAge,
    required this.circaBiologicalAge,
    required this.ageDeltaYears,
    required this.estimatedVo2Max,
    required this.rhrSixMonthTrend,
    required this.weeklyZone2Minutes,
    required this.weeklyZone5Minutes,
    required this.sleepConsistencyPercent,
    required this.headline,
    required this.physiologicalDetails,
  });
}

class HealthspanEngine {
  /// Расчет биологического возраста CIRCA на основе VO2max, RHR тренда и распределения зон нагрузки
  static HealthspanResult calculate({
    int chronologicalAge = 34,
    int restingHeartRate = 52,
    int maxHeartRate = 188,
    int weeklyZone2Minutes = 160,
    int weeklyZone5Minutes = 24,
    double sleepConsistency = 0.88,
    double rhrSixMonthDelta = -2.8, // Пульс покоя снизился за полгода
  }) {
    // 1. Оценка VO2max (формула Uth-Sorensen с коррекцией на объем зоны 2 и 5)
    final baseVo2 = 15.3 * (maxHeartRate / restingHeartRate);
    final trainingBonus = (weeklyZone2Minutes / 60.0) * 0.45 + (weeklyZone5Minutes / 10.0) * 0.6;
    final vo2max = double.parse((baseVo2 + trainingBonus).clamp(25.0, 75.0).toStringAsFixed(1));

    // 2. Вклад кардиореспираторной выносливости в замедление старения
    // VO2max 52+ в 34 года дает омоложение на ~3-4 года
    final vo2AgeBenefit = ((vo2max - 42.0) * 0.35).clamp(-2.0, 4.5);

    // 3. Вклад снижения пульса покоя за 6 месяцев (каждый -1 bpm долгосрочно омолаживает миокард)
    final rhrBenefit = (-rhrSixMonthDelta * 0.6).clamp(-1.5, 2.5);

    // 4. Вклад регулярности сна
    final sleepBenefit = ((sleepConsistency - 0.75) * 4.0).clamp(-1.0, 2.0);

    final totalBenefitYears = vo2AgeBenefit + rhrBenefit + sleepBenefit;
    final biologicalAge = double.parse((chronologicalAge - totalBenefitYears).toStringAsFixed(1));
    final delta = double.parse((-totalBenefitYears).toStringAsFixed(1));

    return HealthspanResult(
      chronologicalAge: chronologicalAge,
      circaBiologicalAge: biologicalAge,
      ageDeltaYears: delta,
      estimatedVo2Max: vo2max,
      rhrSixMonthTrend: rhrSixMonthDelta,
      weeklyZone2Minutes: weeklyZone2Minutes,
      weeklyZone5Minutes: weeklyZone5Minutes,
      sleepConsistencyPercent: (sleepConsistency * 100).round().toDouble(),
      headline: 'Вам $chronologicalAge, телу $biologicalAge года (${delta < 0 ? "$delta" : "+$delta"} г.)',
      physiologicalDetails:
          'Высокая аэробная выносливость (VO2max $vo2max) и 6-месячное снижение ночного пульса покоя на ${rhrSixMonthDelta.abs()} уд/мин обеспечивают превосходный резерв долголетия сосудов и миокарда.',
    );
  }
}
