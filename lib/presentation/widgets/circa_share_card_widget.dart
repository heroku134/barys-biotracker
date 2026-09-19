import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../domain/avatar/avatar_manager.dart';
import '../../domain/intelligence/strain_engine.dart';
import '../../domain/models/personal_baseline.dart';
import '../../domain/models/readiness.dart';
import '../../domain/models/telemetry.dart';

enum ShareCardTheme {
  recovery('Восстановление', 'RECOVERY'),
  strain('Нагрузка', 'STRAIN'),
  barys('Барыс-Батыр', 'BARYS');

  final String label;
  final String code;
  const ShareCardTheme(this.label, this.code);
}

/// Виджет статусной карточки в швейцарском стиле (Swiss Typography / Kinfolk)
/// Предназначен для рендеринга 9:16 истории или постера без дешевых рекламных штампов.
class CircaShareCardWidget extends StatelessWidget {
  final ShareCardTheme theme;
  final BleTelemetry telemetry;
  final PersonalBaseline baseline;
  final ReadinessResult readiness;
  final AvatarProfile avatarProfile;
  final StrainCalculationResult strainResult;
  final String userName;
  final String cityName;

  const CircaShareCardWidget({
    super.key,
    required this.theme,
    required this.telemetry,
    required this.baseline,
    required this.readiness,
    required this.avatarProfile,
    required this.strainResult,
    this.userName = 'Данияр',
    this.cityName = 'ALMATY',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 640,
      decoration: BoxDecoration(
        color: AppColors.stage,
        border: Border.all(color: AppColors.line, width: 1.0),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Верхняя архитектурная сетка (Header)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CIRCA ONE',
                    style: TextStyle(
                      color: AppColors.fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'BIO-METRIC ATELIER · $cityName',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  theme.code,
                  style: TextStyle(
                    color: _getAccentColor(),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.line),
          const SizedBox(height: 18),

          // 2. Основное тело карточки в зависимости от темы
          Expanded(
            child: _buildThemeBody(),
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.line),
          const SizedBox(height: 14),

          // 3. Швейцарский подвал (Quiet Luxury Footer)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ATHLETE: $userName'.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.fg,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'AUTONOMIC RECOVERY INDEX',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.faint,
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'CIRCA ONE · $cityName · 2026',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getAccentColor() {
    switch (theme) {
      case ShareCardTheme.recovery:
        return readiness.zone.color;
      case ShareCardTheme.strain:
        return AppColors.amber;
      case ShareCardTheme.barys:
        return avatarProfile.state.badgeColor;
    }
  }

  Widget _buildThemeBody() {
    switch (theme) {
      case ShareCardTheme.recovery:
        return _buildRecoveryBody();
      case ShareCardTheme.strain:
        return _buildStrainBody();
      case ShareCardTheme.barys:
        return _buildBarysBody();
    }
  }

  // --- ТЕМА 1: ВОССТАНОВЛЕНИЕ (RECOVERY) ---
  Widget _buildRecoveryBody() {
    final zoneColor = readiness.zone.color;
    final zoneLabel = readiness.zone == RecoveryZone.optimal
        ? 'PRIME RECOVERY'
        : (readiness.zone == RecoveryZone.moderate ? 'BALANCED ADAPTATION' : 'REST & REGEN');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DAILY BIO-STATUS',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 6),

        // Гигантское число в швейцарском стиле
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${readiness.score}',
              style: TextStyle(
                color: zoneColor,
                fontSize: 82,
                fontWeight: FontWeight.w900,
                letterSpacing: -4.0,
                height: 0.95,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '%',
              style: TextStyle(
                color: zoneColor.withValues(alpha: 0.8),
                fontSize: 34,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),
        Text(
          zoneLabel,
          style: TextStyle(
            color: zoneColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.4,
          ),
        ),

        const SizedBox(height: 10),
        Text(
          readiness.zone == RecoveryZone.optimal
              ? 'Тонус блуждающего нерва оптимален. Миокард полностью восстановился и готов к пиковым нагрузкам.'
              : (readiness.zone == RecoveryZone.moderate
                  ? 'Ровный физиологический фон. Рекомендуется аэробный объем во 2-й пульсовой зоне.'
                  : 'ЦНС перегружена. Высокий симпатический стресс требует постельного покоя и сна до 22:40.'),
          style: const TextStyle(
            color: AppColors.fg,
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),

        const Spacer(),

        // 4 колонки ночных маркеров (Precision Swiss Grid)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Expanded(child: _buildMetricColumn('HRV rMSSD', '${telemetry.hrv.round()}', 'мс')),
              _buildVerticalHairline(),
              Expanded(child: _buildMetricColumn('RHR NADIR', '${telemetry.restingHeartRate}', 'bpm')),
              _buildVerticalHairline(),
              Expanded(child: _buildMetricColumn('RESP RATE', telemetry.respiratoryRate.toStringAsFixed(1), 'rpm')),
              _buildVerticalHairline(),
              Expanded(
                child: _buildMetricColumn(
                  'SKIN TEMP',
                  '${telemetry.skinTempDeviation >= 0 ? '+' : ''}${telemetry.skinTempDeviation.toStringAsFixed(1)}°',
                  'C',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Векторная кардио-волна
        SizedBox(
          height: 38,
          width: double.infinity,
          child: CustomPaint(
            painter: _MinimalistCardiacPainter(color: zoneColor),
          ),
        ),
      ],
    );
  }

  // --- ТЕМА 2: НАГРУЗКА (STRAIN) ---
  Widget _buildStrainBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CARDIOVASCULAR STRAIN',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 6),

        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              telemetry.currentDayStrain.toStringAsFixed(1),
              style: const TextStyle(
                color: AppColors.amber,
                fontSize: 76,
                fontWeight: FontWeight.w900,
                letterSpacing: -3.0,
                height: 0.95,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '/ 21.0',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),
        Text(
          'WHOOP TRIMP SCALE · ЦЕЛЬ ${strainResult.targetStrainMin.toStringAsFixed(1)}+',
          style: const TextStyle(
            color: AppColors.amber,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
        ),

        const SizedBox(height: 10),
        Text(
          telemetry.currentDayStrain >= strainResult.targetStrainMin
              ? 'Оптимальный диапазон нагрузки достигнут. Сердечно-сосудистая система получила качественный анаболический стимул.'
              : 'Для закрытия дневного бюджета требуется еще ${(strainResult.targetStrainMin - telemetry.currentDayStrain).toStringAsFixed(1)} Strain в аэробной Зоне 2.',
          style: const TextStyle(
            color: AppColors.fg,
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),

        const Spacer(),

        // Сводка активности
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Expanded(child: _buildMetricColumn('КАЛОРИИ', '${telemetry.calories}', 'ккал')),
              _buildVerticalHairline(),
              Expanded(child: _buildMetricColumn('ШАГИ', '${telemetry.steps}', 'день')),
              _buildVerticalHairline(),
              Expanded(
                child: _buildMetricColumn(
                  'ЗОНА 2 (ЧСС)',
                  '${telemetry.zoneMinutes.length > 1 ? telemetry.zoneMinutes[1] : 45}',
                  'мин',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Полоса прогресса
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (telemetry.currentDayStrain / 21.0).clamp(0.0, 1.0),
            backgroundColor: AppColors.raised,
            valueColor: const AlwaysStoppedAnimation(AppColors.amber),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  // --- ТЕМА 3: БАРЫС-БАТЫР (MASCOT) ---
  Widget _buildBarysBody() {
    final badgeColor = avatarProfile.state.badgeColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GUARDIAN PROFILE',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 12),

        // Портрет Барыса в круглом медальоне
        Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: badgeColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.22),
                  blurRadius: 24,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                avatarProfile.state.assetPath,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        Center(
          child: Text(
            avatarProfile.rankTitle.toUpperCase(),
            style: TextStyle(
              color: badgeColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
        ),
        Center(
          child: Text(
            avatarProfile.state.title,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Напутствие Барыса
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Text(
            '«${AvatarManager.getRitualQuote(avatarProfile.state)}»',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),

        const Spacer(),

        // Характеристики Батыра
        Row(
          children: [
            Expanded(
              child: _buildMascotStat('ВЫНОСЛИВОСТЬ', avatarProfile.endurance, AppColors.sage),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMascotStat('СИЛА', avatarProfile.power, AppColors.amber),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMascotStat('ФОКУС', avatarProfile.focus, AppColors.sage),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricColumn(String label, String value, String unit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 7,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.fg,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: const TextStyle(
                color: AppColors.faint,
                fontSize: 8,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMascotStat(String label, int val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Text(
            '$val',
            style: const TextStyle(
              color: AppColors.fg,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalHairline() {
    return Container(
      width: 1,
      height: 24,
      color: AppColors.line,
    );
  }
}

class _MinimalistCardiacPainter extends CustomPainter {
  final Color color;
  _MinimalistCardiacPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final h = size.height;
    final w = size.width;

    path.moveTo(0, h * 0.65);
    path.lineTo(w * 0.20, h * 0.65);
    path.lineTo(w * 0.25, h * 0.58);
    path.lineTo(w * 0.30, h * 0.65);
    path.lineTo(w * 0.42, h * 0.65);
    path.lineTo(w * 0.46, h * 0.75); // Q
    path.lineTo(w * 0.50, h * 0.15); // R
    path.lineTo(w * 0.54, h * 0.88); // S
    path.lineTo(w * 0.58, h * 0.65);
    path.lineTo(w * 0.66, h * 0.55); // T
    path.lineTo(w * 0.74, h * 0.65);
    path.lineTo(w, h * 0.65);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MinimalistCardiacPainter oldDelegate) => false;
}
