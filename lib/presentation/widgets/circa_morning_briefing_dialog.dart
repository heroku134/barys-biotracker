import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/intelligence/readiness_engine.dart';
import '../../domain/intelligence/sleep_engine.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/telemetry.dart';

class CircaMorningBriefingDialog extends StatelessWidget {
  final BleTelemetry telemetry;
  final PersonalBaseline baseline;

  const CircaMorningBriefingDialog({
    super.key,
    required this.telemetry,
    required this.baseline,
  });

  static void show(BuildContext context, BleTelemetry telemetry, PersonalBaseline baseline) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CircaMorningBriefingDialog(telemetry: telemetry, baseline: baseline),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readiness = ReadinessEngine.calculate(telemetry, baseline: baseline);
    final strainResult = StrainEngine.evaluate(
      currentStrain: telemetry.currentDayStrain,
      recoveryZone: readiness.zone,
      zoneMinutes: telemetry.zoneMinutes,
    );
    final sleepResult = SleepEngine.calculate(telemetry: telemetry, baseline: baseline);
    final quote = AvatarManager.getMorningQuote(readiness.zone, strainResult.targetStrainMin);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.stage,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.lineStrong, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 30,
            ),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Хедер
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CIRCA MORNING BRIEFING',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '07:00 · Утренний физиологический отчет',
                      style: TextStyle(
                        color: AppColors.faint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: readiness.zone.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    readiness.zone.badgeText,
                    style: TextStyle(
                      color: readiness.zone.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Три ключевые цифры дня: Recovery, Бюджет Strain, Bedtime
            Row(
              children: [
                _buildMetricBlock(
                  label: 'RECOVERY',
                  value: '${readiness.score}%',
                  sub: readiness.zone.label,
                  color: readiness.zone.color,
                ),
                const SizedBox(width: 8),
                _buildMetricBlock(
                  label: 'БЮДЖЕТ STRAIN',
                  value: '${strainResult.targetStrainMin.toStringAsFixed(1)}–${strainResult.targetStrainMax.toStringAsFixed(1)}',
                  sub: 'Целевая шкала',
                  color: AppColors.amber,
                ),
                const SizedBox(width: 8),
                _buildMetricBlock(
                  label: 'ОТБОЙ СЕГОДНЯ',
                  value: sleepResult.optimalBedtime,
                  sub: 'Для 100% сна',
                  color: AppColors.cyan,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Напутствие Барыс-Батыра
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.amber, width: 1.5),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/hero_barys_charged.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'НАПУТСТВИЕ БАТЫРА',
                          style: TextStyle(
                            color: AppColors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          quote,
                          style: const TextStyle(
                            color: AppColors.fg,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Кнопка подтверждения
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.stage,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'ПРИНЯТЬ ПЛАН НА ДЕНЬ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBlock({
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.faint,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
