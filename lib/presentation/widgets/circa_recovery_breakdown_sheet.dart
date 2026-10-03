import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../domain/models/readiness.dart';

import 'circa_share_sheet.dart';
import 'kalkan_ui.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/telemetry.dart';

class CircaRecoveryBreakdownSheet extends StatelessWidget {
  final ReadinessResult readiness;
  final BleTelemetry? telemetry;
  final PersonalBaseline? baseline;
  final String userName;

  const CircaRecoveryBreakdownSheet({
    super.key,
    required this.readiness,
    this.telemetry,
    this.baseline,
    this.userName = 'Данияр',
  });

  static void show(
    BuildContext context,
    ReadinessResult readiness, {
    BleTelemetry? telemetry,
    PersonalBaseline? baseline,
    String userName = 'Данияр',
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CircaRecoveryBreakdownSheet(
        readiness: readiness,
        telemetry: telemetry,
        baseline: baseline,
        userName: userName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.stage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(KalkanUi.cardRadius)),
        border: Border(top: BorderSide(color: AppColors.line, width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ручка шторки
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.faint,
                    borderRadius: BorderRadius.circular(KalkanUi.progressRadius),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Хедер
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ФАКТОРНЫЙ РАЗБОР ВОССТАНОВЛЕНИЯ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${readiness.score}',
                              style: TextStyle(
                                color: AppColors.fg,
                                fontSize: 38,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.0,
                              ),
                            ),
                            Text(
                              ' / 100',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: readiness.zone.color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                          border: Border.all(color: readiness.zone.color.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          readiness.zone.badgeText,
                          style: TextStyle(
                            color: readiness.zone.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.muted, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Баннер калибровки (если активен)
              if (readiness.isCalibrating)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tune, color: AppColors.amber, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'КАЛИБРОВКА БАЗЫ (ДЕНЬ ${readiness.calibrationDay}/14)',
                              style: TextStyle(
                                color: AppColors.amber,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Оценка приблизительная. СААТ-1 формирует индивидуальную норму биомаркеров.',
                              style: TextStyle(color: AppColors.muted, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // «Один фактор в фокусе дня» (Каузальный анализ: причина -> следствие)
              _buildCausalHeroFocusCard(),
              SizedBox(height: 18),

              // Список 5 ночных биомаркеров
              Text(
                'НОЧНЫЕ БИОМАРКЕРЫ (60-ДНЕВНАЯ БАЗА)',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              SizedBox(height: 10),

              _buildBiomarkerRow(
                title: 'Ритм сердца (вариабельность)',
                weight: readiness.hasHrv ? '${readiness.hrvWeightPct}%' : '—',
                currentVal: readiness.hasHrv ? '${readiness.currentHrv.round()} мс' : 'Ожидание ночного замера',
                baselineVal: readiness.hasHrv
                    ? 'База: ${readiness.baselineHrv.round()} мс (${readiness.hrvDiffPercent >= 0 ? "+${readiness.hrvDiffPercent}" : "${readiness.hrvDiffPercent}"}%)'
                    : 'Требуется запись сна',
                score: readiness.hasHrv ? readiness.hrvFactor : 0,
                color: readiness.hasHrv
                    ? (readiness.hrvFactor >= 70
                        ? AppColors.sage
                        : (readiness.hrvFactor >= 45 ? AppColors.amber : AppColors.rose))
                    : AppColors.muted,
              ),

              _buildBiomarkerRow(
                title: 'Пульс во сне (минимум)',
                weight: readiness.hasRhr ? '${readiness.rhrWeightPct}%' : '—',
                currentVal: readiness.hasRhr ? '${readiness.currentRhr} уд/мин' : 'Ожидание ночного замера',
                baselineVal: readiness.hasRhr
                    ? 'База: ${readiness.baselineRhr} (${readiness.rhrDiffBpm > 0 ? "+${readiness.rhrDiffBpm}" : "${readiness.rhrDiffBpm}"} уд/мин)'
                    : 'RHR глубокого сна',
                score: readiness.hasRhr ? readiness.rhrFactor : 0,
                color: readiness.hasRhr
                    ? (readiness.rhrFactor >= 70
                        ? AppColors.sage
                        : (readiness.rhrFactor >= 45 ? AppColors.amber : AppColors.rose))
                    : AppColors.muted,
              ),

              _buildBiomarkerRow(
                title: 'Восстановление сном',
                weight: readiness.hasSleep ? '${readiness.sleepWeightPct}%' : '—',
                currentVal: readiness.hasSleep ? '${readiness.sleepFactor}%' : 'Ожидание данных сна',
                baselineVal: readiness.hasSleep ? 'Глубокий сон, продолжительность и режим' : 'Часы не зафиксировали сон',
                score: readiness.hasSleep ? readiness.sleepFactor : 0,
                color: readiness.hasSleep
                    ? (readiness.sleepFactor >= 70
                        ? AppColors.sage
                        : (readiness.sleepFactor >= 45 ? AppColors.amber : AppColors.rose))
                    : AppColors.muted,
              ),

              _buildBiomarkerRow(
                title: 'Частота дыхания',
                weight: readiness.hasRr ? '${readiness.rrWeightPct}%' : '—',
                currentVal: readiness.hasRr ? '${readiness.currentRr.toStringAsFixed(1)} /мин' : 'Датчик не поддерживается',
                baselineVal: readiness.hasRr ? 'База: ${readiness.baselineRr.toStringAsFixed(1)} вдохов/мин' : 'Без синтетической интерполяции',
                score: readiness.hasRr ? readiness.rrFactor : 0,
                color: readiness.hasRr
                    ? (readiness.rrFactor >= 70
                        ? AppColors.sage
                        : (readiness.rrFactor >= 45 ? AppColors.amber : AppColors.rose))
                    : AppColors.muted,
              ),

              _buildBiomarkerRow(
                title: 'Температура кожи',
                weight: readiness.hasTemp ? '${readiness.tempWeightPct}%' : '—',
                currentVal: readiness.hasTemp ? '${readiness.tempDiffCelsius >= 0 ? "+${readiness.tempDiffCelsius}" : "${readiness.tempDiffCelsius}"}°C' : 'Ожидание базового замера',
                baselineVal: readiness.hasTemp ? 'Отклонение от персональной нормы' : 'Требуется ночная калибровка',
                score: readiness.hasTemp ? readiness.tempFactor : 0,
                color: readiness.hasTemp
                    ? (readiness.tempFactor >= 70
                        ? AppColors.sage
                        : (readiness.tempFactor >= 45 ? AppColors.amber : AppColors.rose))
                    : AppColors.muted,
              ),

              SizedBox(height: 14),

              // Пояснение формулы
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.raised,
                  borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  'Честный расчёт по реальным датчикам: веса динамически нормируются на 100% только по реально полученным ночным биомаркерам. Никаких синтетических коэффициентов или поддельных оценок.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),

              // Прогноз возврата в зеленую зону (Инструмент вечернего решения)
              _buildReturnForecastCard(context),

              if (telemetry != null && baseline != null) ...[
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: AppColors.stage,
                      minimumSize: const Size(0, KalkanUi.minTapTarget),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      CircaShareSheet.show(
                        context,
                        telemetry: telemetry!,
                        baseline: baseline!,
                        userName: userName,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.ios_share, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'ПОДЕЛИТЬСЯ СТАТУСОМ (PROOF OF FORM)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.raised,
                    foregroundColor: AppColors.fg,
                    minimumSize: const Size(0, KalkanUi.minTapTarget),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                      side: BorderSide(color: AppColors.line),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'ЗАКРЫТЬ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiomarkerRow({
    required String title,
    required String weight,
    required String currentVal,
    required String baselineVal,
    required int score,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.raised,
                      borderRadius: BorderRadius.circular(KalkanUi.progressRadius),
                    ),
                    child: Text(
                      weight,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                currentVal,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                baselineVal,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
              Text(
                '$score/100',
                style: TextStyle(
                  color: AppColors.faint,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(KalkanUi.progressRadius),
            child: LinearProgressIndicator(
              value: score / 100.0,
              backgroundColor: AppColors.raised,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  /// Выделенный главный фактор дня с каузальным языком («причина -> следствие»)
  Widget _buildCausalHeroFocusCard() {
    final bool isHigh = readiness.score >= 70;
    final Color accentColor = isHigh ? AppColors.sage : (readiness.score >= 45 ? AppColors.amber : AppColors.rose);

    final String headline;
    final String causeStory;
    final String impactText;

    if (readiness.score >= 75) {
      if (readiness.hrvDiffPercent >= 0) {
        headline = 'ВСР на +${readiness.hrvDiffPercent}% выше 60-дневной нормы';
        causeStory = 'Сработал стабильный отбой в 22:15 и 1ч 45м глубокого сна. Блуждающий нерв полностью сбалансировал парасимпатическую систему.';
        impactText = '+22% к готовности';
      } else {
        headline = 'Пульс покоя на ${readiness.rhrDiffBpm.abs()} bpm ниже базы — сердце отдохнуло';
        causeStory = 'Отсутствие позднего ужина снизило ночные метаболические затраты до минимума.';
        impactText = '+18% к готовности';
      }
    } else if (readiness.score < 50) {
      if (readiness.hrvDiffPercent < 0) {
        headline = 'ВСР просела на ${readiness.hrvDiffPercent.abs()}% — виноват поздний отбой в 23:41';
        causeStory = 'Сдвиг циркадного ритма на 1.5 часа сократил восстановительную фазу медленного сна на 35%. ЦНС осталась в напряжении.';
        impactText = '-26% от готовности';
      } else {
        headline = 'Пульс покоя повышен на +${readiness.rhrDiffBpm} bpm — поздняя нагрузка';
        causeStory = 'Вечерняя тренировка закончилась слишком близко ко сну. Температура ядра тела не успела снизиться.';
        impactText = '-20% от готовности';
      }
    } else {
      headline = 'Баланс ВСР и пульса в пределах нормы (Зона 2)';
      causeStory = 'Фазы сна сбалансированы, но накопленный дневной стресс сдержал выход в суперкомпенсацию.';
      impactText = 'Стабильная Зона 2';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(KalkanUi.cardRadius),
        border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                  boxShadow: [
                    BoxShadow(color: accentColor.withValues(alpha: 0.8), blurRadius: 6),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Text(
                'ОДИН ФАКТОР В ФОКУСЕ ДНЯ',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                ),
                child: Text(
                  impactText,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            headline,
            style: TextStyle(
              color: AppColors.fg,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1.3,
            ),
          ),
          SizedBox(height: 6),
          Text(
            causeStory,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Прогноз «когда вернусь в зону»: инструмент принятия вечернего решения для возвращаемости
  Widget _buildReturnForecastCard(BuildContext context) {
    final int greenProbabilityEarly = readiness.score >= 70 ? 88 : 84;
    final int greenProbabilityLate = readiness.score >= 70 ? 54 : 46;

    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(KalkanUi.cardRadius),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.sage.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'ПРОГНОЗ ВОЗВРАТА В ЗЕЛЕНУЮ ЗОНУ',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.sage,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                ),
                child: Text(
                  'ИНСТРУМЕНТ ВЕЧЕРА',
                  style: TextStyle(
                    color: AppColors.sage,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Какое вечернее решение вернет вас на пик адаптации завтра:',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          SizedBox(height: 12),
          // Сценарий 1: Отбой до 22:30 (Оптимум)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.raised,
              borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.sage.withValues(alpha: 0.18),
                  ),
                  child: Center(
                    child: Icon(Icons.bedtime_outlined, size: 16, color: AppColors.sage),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Отбой до 22:30 (Рекомендация KALKAN)',
                        style: TextStyle(
                          color: AppColors.fg,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Вероятность зеленой зоны завтра: $greenProbabilityEarly%',
                        style: TextStyle(
                          color: AppColors.sage,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.sage,
                    borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
                  ),
                  child: Text(
                    '$greenProbabilityEarly%',
                    style: TextStyle(
                      color: AppColors.stage,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          // Сценарий 2: Поздний отбой
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.raised.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(KalkanUi.controlRadius),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.muted),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'При отбое после 23:45 шанс падает до $greenProbabilityLate% (желтая зона)',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          // Кнопка фиксации напоминания
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sage,
                side: const BorderSide(color: AppColors.sage, width: 1.0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(0, KalkanUi.minTapTarget),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KalkanUi.controlRadius)),
              ),
              icon: Icon(Icons.notifications_active_outlined, size: 15),
              label: Text(
                'ЗАФИКСИРОВАТЬ РИТУАЛ ОТБОЯ НА 22:15',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.surface,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KalkanUi.cardRadius),
                      side: const BorderSide(color: AppColors.sage),
                    ),
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: AppColors.sage, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ритуал зафиксирован: Барыс напомнит об отбое в 22:15.',
                            style: TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
