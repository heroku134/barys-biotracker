import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../domain/models/readiness.dart';

import 'circa_share_sheet.dart';
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Хедер
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
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
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${readiness.score}',
                              style: const TextStyle(
                                color: AppColors.fg,
                                fontSize: 38,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.0,
                              ),
                            ),
                            const Text(
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
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: readiness.zone.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
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
                ],
              ),
              const SizedBox(height: 16),

              // Баннер калибровки (если активен)
              if (readiness.isCalibrating)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, color: AppColors.amber, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Калибровка: День ${readiness.calibrationDay} из 14. Строим ваш личный физиологический профиль (HRV, RHR, RR, температура).',
                          style: const TextStyle(
                            color: AppColors.fg,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Карточка главного сдерживающего фактора
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.rose),
                        const SizedBox(width: 6),
                        const Text(
                          'КЛЮЧЕВОЙ ВЫВОД',
                          style: TextStyle(
                            color: AppColors.rose,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      readiness.primaryNegativeFactor,
                      style: const TextStyle(
                        color: AppColors.fg,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      readiness.primaryPositiveFactor,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Список 5 ночных биомаркеров
              const Text(
                'НОЧНЫЕ БИОМАРКЕРЫ (60-ДНЕВНАЯ БАЗА)',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 10),

              _buildBiomarkerRow(
                title: 'ВСР (rMSSD) в глубоком сне',
                weight: '35%',
                currentVal: '${readiness.currentHrv.round()} мс',
                baselineVal: 'База: ${readiness.baselineHrv.round()} мс (${readiness.hrvDiffPercent >= 0 ? "+${readiness.hrvDiffPercent}" : "${readiness.hrvDiffPercent}"}%)',
                score: readiness.hrvFactor,
                color: readiness.hrvFactor >= 70
                    ? AppColors.sage
                    : (readiness.hrvFactor >= 45 ? AppColors.amber : AppColors.rose),
              ),

              _buildBiomarkerRow(
                title: 'Пульс покоя (RHR Nadir)',
                weight: '25%',
                currentVal: '${readiness.currentRhr} уд/мин',
                baselineVal: 'База: ${readiness.baselineRhr} (${readiness.rhrDiffBpm > 0 ? "+${readiness.rhrDiffBpm}" : "${readiness.rhrDiffBpm}"} bpm)',
                score: readiness.rhrFactor,
                color: readiness.rhrFactor >= 70
                    ? AppColors.sage
                    : (readiness.rhrFactor >= 45 ? AppColors.amber : AppColors.rose),
              ),

              _buildBiomarkerRow(
                title: 'Качество сна (Sleep Performance)',
                weight: '20%',
                currentVal: '${readiness.sleepFactor}%',
                baselineVal: 'Длительность + Эффективность + Consistency',
                score: readiness.sleepFactor,
                color: readiness.sleepFactor >= 70
                    ? AppColors.sage
                    : (readiness.sleepFactor >= 45 ? AppColors.amber : AppColors.rose),
              ),

              _buildBiomarkerRow(
                title: 'Частота дыхания (RR)',
                weight: '10%',
                currentVal: '${readiness.currentRr.toStringAsFixed(1)} /мин',
                baselineVal: 'База: ${readiness.baselineRr.toStringAsFixed(1)} вдохов/мин',
                score: readiness.rrFactor,
                color: readiness.rrFactor >= 70
                    ? AppColors.sage
                    : (readiness.rrFactor >= 45 ? AppColors.amber : AppColors.rose),
              ),

              _buildBiomarkerRow(
                title: 'Температура кожи (ΔT)',
                weight: '10%',
                currentVal: '${readiness.tempDiffCelsius >= 0 ? "+${readiness.tempDiffCelsius}" : "${readiness.tempDiffCelsius}"}°C',
                baselineVal: 'Отклонение от ночной медианы',
                score: readiness.tempFactor,
                color: readiness.tempFactor >= 70
                    ? AppColors.sage
                    : (readiness.tempFactor >= 45 ? AppColors.amber : AppColors.rose),
              ),

              const SizedBox(height: 14),

              // Пояснение формулы
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.raised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Text(
                  'Формула: 0.35·ВСР + 0.25·RHR + 0.20·Сон + 0.10·Дыхание + 0.10·Кожа. Дневная нагрузка (Strain) исключена из формулы.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),

              if (telemetry != null && baseline != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: AppColors.stage,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
                    child: const Row(
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
        borderRadius: BorderRadius.circular(12),
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
                    style: const TextStyle(
                      color: AppColors.fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.raised,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      weight,
                      style: const TextStyle(
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
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                baselineVal,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
              Text(
                '$score/100',
                style: const TextStyle(
                  color: AppColors.faint,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
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
}
