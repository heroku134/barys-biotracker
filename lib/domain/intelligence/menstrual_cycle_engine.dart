import 'dart:math' as math;
import '../../core/app_language.dart';
import '../models/telemetry.dart';
import '../models/user_profile.dart';

/// Данные расширенного анализа женского биоритма на основе датчиков СААТ-1
class CycleAnalysisResult {
  final int currentDay;
  final int totalDays;
  final HormonalCyclePhase phase;
  final double skinTempDeviation;
  final String thermalStatusText;
  final String thermalAdviceText;
  final double targetStrainMin;
  final double targetStrainMax;
  final String trainingDirective;
  final String nutritionDirective;
  final String sleepDirective;
  final String barysQuote;
  final bool isThermalShiftConfirmed;
  final double predictedNextTempDelta;

  const CycleAnalysisResult({
    required this.currentDay,
    required this.totalDays,
    required this.phase,
    required this.skinTempDeviation,
    required this.thermalStatusText,
    required this.thermalAdviceText,
    required this.targetStrainMin,
    required this.targetStrainMax,
    required this.trainingDirective,
    required this.nutritionDirective,
    required this.sleepDirective,
    required this.barysQuote,
    required this.isThermalShiftConfirmed,
    required this.predictedNextTempDelta,
  });
}

/// Физиологический движок анализа менструального цикла и связки с сенсорами часов «СААТ-1»
class MenstrualCycleEngine {
  /// Расчет текущего дня цикла на основе даты последних месячных
  static int calculateCurrentCycleDay(DateTime? lastPeriodStart, {int cycleLength = 28}) {
    if (lastPeriodStart == null) return 14; // Середина цикла по умолчанию
    final now = DateTime.now();
    final differenceDays = now.difference(lastPeriodStart).inDays;
    if (differenceDays < 0) return 1;
    return (differenceDays % cycleLength) + 1;
  }

  /// Определение фазы по номеру дня цикла
  static HormonalCyclePhase determinePhase(int day, {int cycleLength = 28, int periodDuration = 5}) {
    final ovulationDay = (cycleLength / 2).round(); // Обычно 14 день при 28-дневном
    if (day <= periodDuration) {
      return HormonalCyclePhase.menstrual;
    } else if (day < ovulationDay) {
      return HormonalCyclePhase.follicular;
    } else if (day <= ovulationDay + 2) {
      return HormonalCyclePhase.ovulatory;
    } else {
      return HormonalCyclePhase.luteal;
    }
  }

  static int ovulationDay({int cycleLength = 28}) => (cycleLength / 2).round();

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int cycleDayForDate(DateTime date, DateTime? lastPeriodStart, {int cycleLength = 28}) {
    if (lastPeriodStart == null) return 1;
    final start = dateOnly(lastPeriodStart);
    final day = dateOnly(date);
    final diff = day.difference(start).inDays;
    if (diff < 0) return 1;
    return (diff % cycleLength) + 1;
  }

  static DateTime dateForCycleDay(DateTime lastPeriodStart, int cycleDay) {
    return dateOnly(lastPeriodStart).add(Duration(days: cycleDay - 1));
  }

  static DateTime nextPeriodStart(DateTime? lastPeriodStart, {int cycleLength = 28}) {
    final start = dateOnly(lastPeriodStart ?? DateTime.now());
    var next = start.add(Duration(days: cycleLength));
    final today = dateOnly(DateTime.now());
    while (!next.isAfter(today)) {
      next = next.add(Duration(days: cycleLength));
    }
    return next;
  }

  static DateTime predictedOvulation(DateTime? lastPeriodStart, {int cycleLength = 28}) {
    final start = dateOnly(lastPeriodStart ?? DateTime.now());
    return start.add(Duration(days: ovulationDay(cycleLength: cycleLength) - 1));
  }

  static DateTime fertileStart(DateTime? lastPeriodStart, {int cycleLength = 28}) {
    return predictedOvulation(lastPeriodStart, cycleLength: cycleLength).subtract(const Duration(days: 4));
  }

  static DateTime fertileEnd(DateTime? lastPeriodStart, {int cycleLength = 28}) {
    return predictedOvulation(lastPeriodStart, cycleLength: cycleLength).add(const Duration(days: 1));
  }

  static int daysUntil(DateTime target) {
    return dateOnly(target).difference(dateOnly(DateTime.now())).inDays;
  }

  /// Ожидаемое физиологическое отклонение ночной температуры кожи (°C) для каждого дня цикла
  static double expectedThermalDelta(int day, {int cycleLength = 28}) {
    final ovulationDay = (cycleLength / 2).round();
    if (day < ovulationDay - 1) {
      // Фолликулярная: прохладная фаза (-0.2°C .. -0.3°C)
      return -0.25 + 0.05 * math.sin(day);
    } else if (day >= ovulationDay - 1 && day <= ovulationDay + 1) {
      // Овуляторный двухфазный скачок (+0.1°C .. +0.3°C)
      return 0.20;
    } else {
      // Лютеиновая: прогестероновое плато (+0.35°C .. +0.55°C)
      return 0.42 + 0.06 * math.cos(day);
    }
  }

  /// Комплексный анализ телеметрии СААТ-1 для женского организма
  static CycleAnalysisResult analyze({
    required BleTelemetry telemetry,
    required UserProfile profile,
    AppLanguage language = AppLanguage.russian,
  }) {
    final cycleLength = profile.cycleLengthDays > 0 ? profile.cycleLengthDays : 28;
    final periodDuration = profile.periodDurationDays > 0 ? profile.periodDurationDays : 5;
    final currentDay = profile.lastPeriodStartDate != null
        ? calculateCurrentCycleDay(profile.lastPeriodStartDate, cycleLength: cycleLength)
        : (profile.cycleDay ?? 14).clamp(1, cycleLength);

    final phase = determinePhase(currentDay, cycleLength: cycleLength, periodDuration: periodDuration);
    final skinTemp = telemetry.skinTempDeviation;
    final expectedTemp = expectedThermalDelta(currentDay, cycleLength: cycleLength);
    final isShiftConfirmed = (skinTemp - expectedTemp).abs() < 0.45;

    // Расчет адаптивного бюджета нагрузки Strain на день
    double strainMin = 10.0;
    double strainMax = 14.0;
    String trainingText = '';
    String nutritionText = '';
    String sleepText = '';
    String barysText = '';
    String thermalStatus = '';
    String thermalAdvice = '';

    final isKg = language == AppLanguage.kyrgyz;
    final isEn = language == AppLanguage.english;

    switch (phase) {
      case HormonalCyclePhase.menstrual:
        strainMin = 6.0;
        strainMax = 9.5;
        thermalStatus = isKg
            ? 'СААТ-1 термосенсору: Базалык деңгээл (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)'
            : (isEn
                ? 'SAAT-1 thermosensor: Baseline level (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)'
                : 'Термосенсор СААТ-1: Базовый уровень (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)');
        thermalAdvice = isKg
            ? 'Прогестерон төмөн, дене температурасы калыбына келүүдө.'
            : (isEn
                ? 'Progesterone is low, body temperature is stable at its baseline.'
                : 'Прогестерон на нуле, температура тела стабильна на минимальной планке.');
        trainingText = isKg
            ? 'Регенеративдик кыймыл: 2-Зонада сейилдөө, сунуу жана жеңил йога. Оор күч көнүгүүлөрүнөн эс алыңыз.'
            : (isEn
                ? 'Regenerative movement: Zone 2 walks, gentle stretching and light mobility. Reduce axial load.'
                : 'Восстановительное движение: прогулки в Зоне 2, мягкая растяжка и мобильность. Снизьте осевые нагрузки.');
        nutritionText = isKg
            ? 'Темир (темирге бай азыктар), магний жана жылуу шорполорду көбөйтүңүз. Гидратация 2.5л+.'
            : (isEn
                ? 'Replenish iron stores, add magnesium and warm herbal tea. Maintain 2.5L+ hydration.'
                : 'Восполняйте запасы железа, добавьте магний и теплые травяные чаи. Обильное теплое питье.');
        sleepText = isKg
            ? 'Уйку бөлмөсүнүн температурасы: 19°C. Уйкуга +30 мүнөт кошумча бөлүү сунушталат.'
            : (isEn
                ? 'Bedroom temperature 19°C. SAAT-1 recommends extending sleep window by 35–45 minutes.'
                : 'Температура спальни 19°C. СААТ-1 рекомендует увеличить окно сна на 35–45 минут.');
        barysText = isKg
            ? '«Күч тыныгууда топтолот. Илбирс секирер алдында бугуп жатат.»'
            : (isEn
                ? '“Strength gathers in rest. The Snow Leopard rests in its den before a great leap.”'
                : '«Сила копится в покое. Барс перед дальним прыжком замирает в логове.»');
        break;

      case HormonalCyclePhase.follicular:
        strainMin = 12.0;
        strainMax = 16.5;
        thermalStatus = isKg
            ? 'СААТ-1 термосенсору: Прохладная фаза (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)'
            : (isEn
                ? 'SAAT-1 thermosensor: Cool phase (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)'
                : 'Термосенсор СААТ-1: Прохладная фаза (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)');
        thermalAdvice = isKg
            ? 'Эстрогендин өсүшү: ЖЖВ (HRV) эң жогорку чегинде, чарчоо босогосу өтө жогору.'
            : (isEn
                ? 'Estrogen rise: HRV at peak, resting heart rate minimal. Nervous system ready for PRs.'
                : 'Рост эстрогена: ВСР на пике, пульс покоя минимален. Нервная система готова к рекордам.');
        trainingText = isKg
            ? 'Эң жогорку күч: Оор штанга, спринттер жана жогорку интенсивдүү машыгуулар (HIIT). Жаңы рекордор убактысы!'
            : (isEn
                ? 'Peak anabolism: Heavy lifting, sprints and high-intensity intervals (HIIT). Best window for personal records!'
                : 'Пик анаболизма: тяжелые силовые тренировки, спринты и интервалы (HIIT). Лучшее окно для личных рекордов!');
        nutritionText = isKg
            ? 'Татаал углеводдор жана сапаттуу протеин. Гликоген запасы максималдуу сиңет.'
            : (isEn
                ? 'Complex carbs and clean protein. Insulin sensitivity is high, glycogen absorbs optimally into muscles.'
                : 'Сложные углеводы и чистый протеин. Инсулинорезистентность низкая, гликоген отлично усваивается мышцами.');
        sleepText = isKg
            ? 'Терең уйкунун сапаты 85%+. Организм тез калыбына келет.'
            : (isEn
                ? 'Deep NREM sleep ratio 85%+. Body recovers quickly.'
                : 'Высокая доля глубокого NREM сна. Тело мгновенно восстанавливает мышечные волокна.');
        barysText = isKg
            ? '«Тоолор сенин күчүңө баш иет. Бүгүн артка чегинүү жок!»'
            : (isEn
                ? '“The mountains yield to your strength. Time to conquer new summits!”'
                : '«Твои мышцы заряжены горной мощью. Время покорять новые вершины!»');
        break;

      case HormonalCyclePhase.ovulatory:
        strainMin = 13.0;
        strainMax = 17.5;
        thermalStatus = isKg
            ? 'СААТ-1: Термикалык секирик катталды (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)'
            : (isEn
                ? 'SAAT-1: Thermal shift recorded (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)'
                : 'СААТ-1: Зафиксирован термический сдвиг (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)');
        thermalAdvice = isKg
            ? 'Овуляция фазасы: Эстроген менен күчтүн абсолюттук туу чокусу.'
            : (isEn
                ? 'Ovulatory window: Peak endurance and neuromuscular coordination.'
                : 'Овуляторное окно: пиковый уровень выносливости и нейромышечной координации.');
        trainingText = isKg
            ? 'Максималдуу күч жана ылдамдык. Бирок муундардын чоюлгучтугу көбөйгөндүктөн, жакшы жылыныңыз!'
            : (isEn
                ? 'Maximum explosive power and coordination. Warm up joints thoroughly before heavy loads.'
                : 'Максимальная взрывная сила и координация. Тщательно разминайте связки перед предельными весами.');
        nutritionText = isKg
            ? 'Антиоксиданттар, жашылчалар, жеңил сиңүүчү белок жана омега-3 майлары.'
            : (isEn
                ? 'Antioxidants, fresh greens, omega-3 and hydration with electrolytes.'
                : 'Антиоксиданты, свежая зелень, омега-3 и гидратация с электролитами.');
        sleepText = isKg
            ? 'СААТ-1 пульс монитору туруктуу. Уктоо убактысын 22:30 чейин сактаңыз.'
            : (isEn
                ? 'SAAT-1 deep sleep tracker steady. Aim to be in bed by 11:00 PM to protect hormone peak.'
                : 'Датчик глубокого сна СААТ-1 в норме. Старайтесь лечь до 23:00 для защиты пика гормонов.');
        barysText = isKg
            ? '«Жаанын огундай курч көз ирмем. Дараметиң туу чокуда!»'
            : (isEn
                ? '“You are at your absolute physiological peak. Energy overflows!”'
                : '«Ты на абсолютном физиологическом пике. Энергия бьет ключом!»');
        break;

      case HormonalCyclePhase.luteal:
        strainMin = 8.0;
        strainMax = 11.5;
        thermalStatus = isKg
            ? 'СААТ-1: Прогестерон жылуулугу (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)'
            : (isEn
                ? 'SAAT-1: Progesterone plateau (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)'
                : 'СААТ-1: Прогестероновое плато (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)');
        thermalAdvice = isKg
            ? 'Тамыр согушу +2..4 согуу/мүн көбөйөт, ЖЖВ 10-15% төмөндөйт. Бул табигый көрүнүш, чарчоо эмес!'
            : (isEn
                ? 'Deep sleep pulse +2..4 bpm higher, HRV naturally lower by 10-15%. This is normal adaptation, not overtraining!'
                : 'Пульс глубокого сна выше на 2–4 bpm, ВСР естественным образом ниже на 10–15%. Это не перетрен!');
        trainingText = isKg
            ? 'СААТ-1 Strain максатын автоматтык түрдө азайтты: 2-Зонадагы темптик чуркоо, пилатес же бассейн.'
            : (isEn
                ? 'SAAT-1 automatically moderated Strain target: Zone 2 aerobic, swimming or pilates without burnout.'
                : 'СААТ-1 автоматически смягчил лимит Strain: аэробная Зона 2, плавание или пилатес без отказа.');
        nutritionText = isKg
            ? 'Метаболизм +150-250 ккал көбөйөт. Көбүрөөк татаал углеводдор жана В6 витамини.'
            : (isEn
                ? 'Metabolism increased by +150-250 kcal. Do not cut calories, add slow carbohydrates and vitamin B6.'
                : 'Базальный метаболизм ускорен на 150–250 ккал. Не урезайте калории, добавьте медленные углеводы.');
        sleepText = isKg
            ? 'Дене ысып калат: уктоочу бөлмөнү 18°C чейин муздатып, салкын төшөк колдонуңуз.'
            : (isEn
                ? 'Body runs warmer. Cool bedroom down to 18°C and ventilate before sleep for easier rest.'
                : 'Тело теплее обычного. Охладите спальню до 18°C и проветрите перед сном для легкого засыпания.');
        barysText = isKg
            ? '«Өзүңө күч келтирбе. Акылман жоокер денесин уга билет.»'
            : (isEn
                ? '“Listen to your body. SAAT-1 preserves your vitality for the next ascent.”'
                : '«Прислушайся к телу. СААТ-1 бережет твои ресурсы до нового восхождения.»');
        break;
    }

    return CycleAnalysisResult(
      currentDay: currentDay,
      totalDays: cycleLength,
      phase: phase,
      skinTempDeviation: skinTemp,
      thermalStatusText: thermalStatus,
      thermalAdviceText: thermalAdvice,
      targetStrainMin: strainMin,
      targetStrainMax: strainMax,
      trainingDirective: trainingText,
      nutritionDirective: nutritionText,
      sleepDirective: sleepText,
      barysQuote: barysText,
      isThermalShiftConfirmed: isShiftConfirmed,
      predictedNextTempDelta: expectedTemp,
    );
  }
}
