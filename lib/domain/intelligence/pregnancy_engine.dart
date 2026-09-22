class PregnancyStatus {
  final int week;
  final int dayInWeek;
  final int trimester;
  final int daysUntilDue;
  final double strainMin;
  final double strainMax;
  final String trainingRu;
  final String trainingKy;
  final String bodyRu;
  final String bodyKy;

  const PregnancyStatus({
    required this.week,
    required this.dayInWeek,
    required this.trimester,
    required this.daysUntilDue,
    required this.strainMin,
    required this.strainMax,
    required this.trainingRu,
    required this.trainingKy,
    required this.bodyRu,
    required this.bodyKy,
  });
}

class PregnancyEngine {
  static const pregnancyDays = 280;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime dueFromLmp(DateTime lmp) => dateOnly(lmp).add(const Duration(days: pregnancyDays));

  static DateTime lmpFromDue(DateTime due) => dateOnly(due).subtract(const Duration(days: pregnancyDays));

  static PregnancyStatus analyze({DateTime? due, DateTime? lmp, DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final start = lmp != null
        ? dateOnly(lmp)
        : (due != null ? lmpFromDue(due) : today.subtract(const Duration(days: 84)));
    final dueDate = due != null ? dateOnly(due) : dueFromLmp(start);
    final elapsed = today.difference(start).inDays.clamp(0, pregnancyDays);
    final week = (elapsed ~/ 7).clamp(1, 42);
    final dayInWeek = elapsed % 7;
    final left = dueDate.difference(today).inDays;
    final trimester = week <= 13 ? 1 : (week <= 27 ? 2 : 3);

    double minS = 6, maxS = 10;
    String ru;
    String ky;
    String bodyRu;
    String bodyKy;
    if (trimester == 1) {
      minS = 5; maxS = 9;
      ru = 'Первый триместр: ходьба, мобильность. Без интервалов и жары.';
      ky = 'Биринчи триместр: басуу, мобилдүүлүк. Интервал жана ысык жок.';
      bodyRu = 'Пульс покоя часто уже выше. Это не обязательно перетрен.';
      bodyKy = 'Тынч пульс көп учурда жогору. Бул сөзсүз чарчоо эмес.';
    } else if (trimester == 2) {
      minS = 7; maxS = 12;
      ru = 'Второй триместр: обычно самый рабочий. Зона 2, сила без задержки дыхания.';
      ky = 'Экинчи триместр: көбүнчө эң ийкемдүү. 2-зона, демди кармабаган күч.';
      bodyRu = 'HRV может быть ниже обычного. Смотрите самочувствие, не только кольцо.';
      bodyKy = 'HRV кадимкиден төмөн болушу мүмкүн. Өзүңүздү да уккула.';
    } else {
      minS = 4; maxS = 8;
      ru = 'Третий триместр: короткие прогулки, таз, дыхание. Strain низкий — это норма.';
      ky = 'Үчүнчү триместр: кыска сейилдөө, жамбаш, дем алуу. Төмөн strain — норма.';
      bodyRu = 'Пульс покоя +10…15 к добеременному — частая картина.';
      bodyKy = 'Тынч пульс +10…15 — көп кездешет.';
    }

    return PregnancyStatus(
      week: week,
      dayInWeek: dayInWeek,
      trimester: trimester,
      daysUntilDue: left,
      strainMin: minS,
      strainMax: maxS,
      trainingRu: ru,
      trainingKy: ky,
      bodyRu: bodyRu,
      bodyKy: bodyKy,
    );
  }
}
