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

    switch (phase) {
      case HormonalCyclePhase.menstrual:
        strainMin = 6.0;
        strainMax = 9.5;
        thermalStatus = isKg
            ? 'СААТ-1 термосенсору: Базалык деңгээл (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)'
            : 'Термосенсор СААТ-1: Базовый уровень (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)';
        thermalAdvice = isKg
            ? 'Прогестерон төмөн, дене температурасы калыбына келүүдө.'
            : 'Прогестерон на нуле, температура тела стабильна на минимальной планке.';
        trainingText = isKg
            ? 'Регенеративдик кыймыл: 2-Зонада сейилдөө, сунуу жана жеңил йога. Оор күч көнүгүүлөрүнөн эс алыңыз.'
            : 'Восстановительное движение: прогулки в Зоне 2, мягкая растяжка и мобильность. Снизьте осевые нагрузки.';
        nutritionText = isKg
            ? 'Темир (темирге бай азыктар), магний жана жылуу шорполорду көбөйтүңүз. Гидратация 2.5л+.'
            : 'Восполняйте запасы железа, добавьте магний и теплые травяные чаи. Обильное теплое питье.';
        sleepText = isKg
            ? 'Уйку бөлмөсүнүн температурасы: 19°C. Уйкуга +30 мүнөт кошумча бөлүү сунушталат.'
            : 'Температура спальни 19°C. СААТ-1 рекомендует увеличить окно сна на 35–45 минут.';
        barysText = isKg
            ? '«Күч тыныгууда топтолот. Илбирс секирер алдында бугуп жатат.»'
            : '«Сила копится в покое. Барс перед дальним прыжком замирает в логове.»';
        break;

      case HormonalCyclePhase.follicular:
        strainMin = 12.0;
        strainMax = 16.5;
        thermalStatus = isKg
            ? 'СААТ-1 термосенсору: Прохладная фаза (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)'
            : 'Термосенсор СААТ-1: Прохладная фаза (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)';
        thermalAdvice = isKg
            ? 'Эстрогендин өсүшү: ЖЖВ (HRV) эң жогорку чегинде, чарчоо босогосу өтө жогору.'
            : 'Рост эстрогена: ВСР на пике, пульс покоя минимален. Нервная система готова к рекордам.';
        trainingText = isKg
            ? 'Эң жогорку күч: Оор штанга, спринттер жана жогорку интенсивдүү машыгуулар (HIIT). Жаңы рекордор убактысы!'
            : 'Пик анаболизма: тяжелые силовые тренировки, спринты и интервалы (HIIT). Лучшее окно для личных рекордов!';
        nutritionText = isKg
            ? 'Татаал углеводдор жана сапаттуу протеин. Гликоген запасы максималдуу сиңет.'
            : 'Сложные углеводы и чистый протеин. Инсулинорезистентность низкая, гликоген отлично усваивается мышцами.';
        sleepText = isKg
            ? 'Терең уйкунун сапаты 85%+. Организм тез калыбына келет.'
            : 'Высокая доля глубокого NREM сна. Тело мгновенно восстанавливает мышечные волокна.';
        barysText = isKg
            ? '«Тоолор сенин күчүңө баш иет. Бүгүн артка чегинүү жок!»'
            : '«Твои мышцы заряжены горной мощью. Время покорять новые вершины!»';
        break;

      case HormonalCyclePhase.ovulatory:
        strainMin = 13.0;
        strainMax = 17.5;
        thermalStatus = isKg
            ? 'СААТ-1: Термикалык секирик катталды (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)'
            : 'СААТ-1: Зафиксирован термический сдвиг (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)';
        thermalAdvice = isKg
            ? 'Овуляция фазасы: Эстроген менен күчтүн абсолюттук туу чокусу.'
            : 'Овуляторное окно: пиковый уровень выносливости и нейромышечной координации.';
        trainingText = isKg
            ? 'Максималдуу күч жана ылдамдык. Бирок муундардын чоюлгучтугу көбөйгөндүктөн, жакшы жылыныңыз!'
            : 'Максимальная взрывная сила и координация. Тщательно разминайте связки перед предельными весами.';
        nutritionText = isKg
            ? 'Антиоксиданттар, жашылчалар, жеңил сиңүүчү белок жана омега-3 майлары.'
            : 'Антиоксиданты, свежая зелень, омега-3 и гидратация с электролитами.';
        sleepText = isKg
            ? 'СААТ-1 пульс монитору туруктуу. Уктоо убактысын 22:30 чейин сактаңыз.'
            : 'Датчик глубокого сна СААТ-1 в норме. Старайтесь лечь до 23:00 для защиты пика гормонов.';
        barysText = isKg
            ? '«Жаанын огундай курч көз ирмем. Дараметиң туу чокуда!»'
            : '«Ты на абсолютном физиологическом пике. Энергия бьет ключом!»';
        break;

      case HormonalCyclePhase.luteal:
        strainMin = 8.0;
        strainMax = 11.5;
        thermalStatus = isKg
            ? 'СААТ-1: Прогестерон жылуулугу (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)'
            : 'СААТ-1: Прогестероновое плато (${skinTemp >= 0 ? '+' : ''}${skinTemp.toStringAsFixed(2)}°C)';
        thermalAdvice = isKg
            ? 'Тамыр согушу +2..4 согуу/мүн көбөйөт, ЖЖВ 10-15% төмөндөйт. Бул табигый көрүнүш, чарчоо эмес!'
            : 'Пульс глубокого сна выше на 2–4 bpm, ВСР естественным образом ниже на 10–15%. Это не перетрен!';
        trainingText = isKg
            ? 'СААТ-1 Strain максатын автоматтык түрдө азайтты: 2-Зонадагы темптик чуркоо, пилатес же бассейн.'
            : 'СААТ-1 автоматически смягчил лимит Strain: аэробная Зона 2, плавание или пилатес без отказа.';
        nutritionText = isKg
            ? 'Метаболизм +150-250 ккал көбөйөт. Көбүрөөк татаал углеводдор жана В6 витамини.'
            : 'Базальный метаболизм ускорен на 150–250 ккал. Не урезайте калории, добавьте медленные углеводы.';
        sleepText = isKg
            ? 'Дене ысып калат: уктоочу бөлмөнү 18°C чейин муздатып, салкын төшөк колдонуңуз.'
            : 'Тело теплее обычного. Охладите спальню до 18°C и проветрите перед сном для легкого засыпания.';
        barysText = isKg
            ? '«Өзүңө күч келтирбе. Акылман жоокер денесин уга билет.»'
            : '«Прислушайся к телу. СААТ-1 бережет твои ресурсы до нового восхождения.»';
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
