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
  final double? animationProgress;
  final String? customSerialNo;

  const CircaShareCardWidget({
    super.key,
    required this.theme,
    required this.telemetry,
    required this.baseline,
    required this.readiness,
    required this.avatarProfile,
    required this.strainResult,
    this.userName = 'Данияр',
    this.cityName = 'Алматы',
    this.animationProgress,
    this.customSerialNo,
  });

  /// Проверка на редкую карточку (Рекорд готовности ≥95 или высокий синхрон)
  bool get isRareGold =>
      readiness.score >= 95 || (readiness.score >= 90 && strainResult.currentStrain >= 14.0);

  /// Серийный номер карточки в ювелирном формате
  String get serialNumber {
    if (customSerialNo != null) return customSerialNo!;
    switch (theme) {
      case ShareCardTheme.recovery:
        final numStr = isRareGold ? '007' : '048';
        return 'RECOVERY №$numStr / 2026';
      case ShareCardTheme.strain:
        return 'STRAIN №112 / 2026';
      case ShareCardTheme.barys:
        return 'BATYR №019 / 2026';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (animationProgress ?? 1.0).clamp(0.0, 1.0);

    return Container(
      width: 360,
      height: 640,
      decoration: BoxDecoration(
        color: AppColors.stage,
        border: Border.all(
          color: isRareGold ? AppColors.amber : AppColors.line,
          width: isRareGold ? 1.6 : 1.0,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: isRareGold
            ? [
                BoxShadow(
                  color: AppColors.amber.withValues(alpha: 0.24),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Верхняя архитектурная сетка (Header)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Text(
                            'KALKAN SPORT',
                            style: TextStyle(
                              color: AppColors.fg,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3.2,
                            ),
                          ),
                          if (isRareGold) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.amber.withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                'EDITION PRIVÉE',
                                style: TextStyle(
                                  color: AppColors.amber,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'BIO-METRIC ATELIER · $cityName',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      serialNumber,
                      style: TextStyle(
                        color: isRareGold ? AppColors.amber : AppColors.faint,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isRareGold
                      ? AppColors.amber.withValues(alpha: 0.15)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isRareGold
                        ? AppColors.amber
                        : AppColors.line,
                    width: 1.0,
                  ),
                ),
                child: Text(
                  isRareGold ? 'Редкий' : theme.code,
                  style: TextStyle(
                    color: isRareGold ? AppColors.amber : _getAccentColor(),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 14),
          Container(height: 1, color: isRareGold ? AppColors.amber.withValues(alpha: 0.3) : AppColors.line),
          SizedBox(height: 16),

          // 2. Основное тело карточки в зависимости от темы
          Expanded(
            child: _buildThemeBody(progress),
          ),

          SizedBox(height: 12),
          Container(height: 1, color: isRareGold ? AppColors.amber.withValues(alpha: 0.3) : AppColors.line),
          SizedBox(height: 12),

          // 3. Швейцарский подвал (Quiet Luxury Footer)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.fg,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      isRareGold ? 'GOLD PROOF OF FORM · CERTIFIED' : 'AUTONOMIC RECOVERY INDEX',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isRareGold ? AppColors.amber : AppColors.faint,
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Text(
                'KALKAN СААТ-1 · $cityName · 2026',
                style: TextStyle(
                  color: isRareGold ? AppColors.amber : AppColors.muted,
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
    if (isRareGold) return AppColors.amber;
    switch (theme) {
      case ShareCardTheme.recovery:
        return readiness.zone.color;
      case ShareCardTheme.strain:
        return AppColors.amber;
      case ShareCardTheme.barys:
        return avatarProfile.state.badgeColor;
    }
  }

  Widget _buildThemeBody(double progress) {
    switch (theme) {
      case ShareCardTheme.recovery:
        return _buildRecoveryBody(progress);
      case ShareCardTheme.strain:
        return _buildStrainBody(progress);
      case ShareCardTheme.barys:
        return _buildBarysBody(progress);
    }
  }

  // --- ТЕМА 1: ВОССТАНОВЛЕНИЕ (RECOVERY) ---
  Widget _buildRecoveryBody(double progress) {
    final zoneColor = isRareGold ? AppColors.amber : readiness.zone.color;
    final animatedScore = (readiness.score * progress).round();

    final zoneLabel = isRareGold
        ? 'GOLD PRIME RECOVERY'
        : (readiness.zone == RecoveryZone.optimal
            ? 'PRIME RECOVERY'
            : (readiness.zone == RecoveryZone.moderate ? 'BALANCED ADAPTATION' : 'REST & REGEN'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DAILY BIO-STATUS',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              if (isRareGold) ...[
                SizedBox(width: 12),
                Text(
                  '✦ RARE GOLD RECORD ✦',
                  style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 6),

        // Гигантское число в швейцарском стиле
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$animatedScore',
              style: TextStyle(
                color: zoneColor,
                fontSize: 82,
                fontWeight: FontWeight.w900,
                letterSpacing: -4.0,
                height: 0.95,
              ),
            ),
            SizedBox(width: 4),
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

        SizedBox(height: 8),
        Text(
          zoneLabel,
          style: TextStyle(
            color: zoneColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),

        SizedBox(height: 10),
        Text(
          isRareGold
              ? 'Идеальная физиологическая форма. ЦНС на абсолютном пике восстановления, парасимпатический тонус на максимуме.'
              : (readiness.zone == RecoveryZone.optimal
                  ? 'Тонус блуждающего нерва оптимален. Миокард полностью восстановился и готов к пиковым нагрузкам.'
                  : (readiness.zone == RecoveryZone.moderate
                      ? 'Ровный физиологический фон. Рекомендуется аэробный объем во 2-й пульсовой зоне.'
                      : 'ЦНС перегружена. Высокий симпатический стресс требует постельного покоя и сна до 22:40.')),
          style: TextStyle(
            color: AppColors.fg,
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),

        Spacer(),

        // 4 колонки ночных маркеров (Precision Swiss Grid)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRareGold ? AppColors.amber.withValues(alpha: 0.4) : AppColors.line,
            ),
          ),
          child: Row(
            children: [
              Expanded(child: _buildMetricColumn('HRV rMSSD', '${(telemetry.hrv * progress).round()}', 'мс')),
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

        SizedBox(height: 14),

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
  Widget _buildStrainBody(double progress) {
    final animatedStrain = telemetry.currentDayStrain * progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CARDIOVASCULAR STRAIN',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 6),

        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              animatedStrain.toStringAsFixed(1),
              style: TextStyle(
                color: AppColors.amber,
                fontSize: 76,
                fontWeight: FontWeight.w900,
                letterSpacing: -3.0,
                height: 0.95,
              ),
            ),
            SizedBox(width: 8),
            Text(
              '/ 21.0',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        SizedBox(height: 8),
        Text(
          'KALKAN · ${strainResult.targetStrainMin.toStringAsFixed(0)}–${strainResult.targetStrainMax.toStringAsFixed(0)}',
          style: TextStyle(
            color: AppColors.amber,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
        ),

        SizedBox(height: 10),
        Text(
          telemetry.currentDayStrain >= strainResult.targetStrainMin
              ? 'Оптимальный диапазон нагрузки достигнут. Сердечно-сосудистая система получила качественный анаболический стимул.'
              : 'Для закрытия дневного бюджета требуется еще ${(strainResult.targetStrainMin - telemetry.currentDayStrain).toStringAsFixed(1)} Strain в аэробной Зоне 2.',
          style: TextStyle(
            color: AppColors.fg,
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),

        Spacer(),

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
              Expanded(child: _buildMetricColumn('КАЛОРИИ', '${(telemetry.calories * progress).round()}', 'ккал')),
              _buildVerticalHairline(),
              Expanded(child: _buildMetricColumn('ШАГИ', '${(telemetry.steps * progress).round()}', 'день')),
              _buildVerticalHairline(),
              Expanded(
                child: _buildMetricColumn(
                  'ЗОНА 2 (ЧСС)',
                  '${telemetry.zoneMinutes.length > 1 ? (telemetry.zoneMinutes[1] * progress).round() : 45}',
                  'мин',
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 14),

        // Полоса прогресса
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (animatedStrain / 21.0).clamp(0.0, 1.0),
            backgroundColor: AppColors.raised,
            valueColor: const AlwaysStoppedAnimation(AppColors.amber),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  // --- ТЕМА 3: БАРЫС-БАТЫР (MASCOT) ---
  Widget _buildBarysBody(double progress) {
    final badgeColor = avatarProfile.state.badgeColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GUARDIAN PROFILE',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 12),

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
                avatarProfile.state.assetFor(),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        SizedBox(height: 14),
        Center(
          child: Text(
            avatarProfile.state.title,
            style: TextStyle(
              color: badgeColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ),
        SizedBox(height: 4),
        Center(
          child: Text(
            '${avatarProfile.rankTitle} · Уровень ${avatarProfile.level}',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        Spacer(),

        // 3 RPG атрибута
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Expanded(child: _buildMetricColumn('ВЫНОСЛИВОСТЬ', '${(avatarProfile.endurance * progress).round()}', '/99')),
              _buildVerticalHairline(),
              Expanded(child: _buildMetricColumn('СИЛА', '${(avatarProfile.power * progress).round()}', '/99')),
              _buildVerticalHairline(),
              Expanded(child: _buildMetricColumn('ФОКУС', '${(avatarProfile.focus * progress).round()}', '/99')),
            ],
          ),
        ),

        SizedBox(height: 14),

        // Реплика Барыса
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.raised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Icon(Icons.format_quote, color: AppColors.amber, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  AvatarManager.getRitualQuote(avatarProfile.state),
                  style: TextStyle(
                    color: AppColors.fg,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricColumn(String label, String value, String unit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: AppColors.fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  color: AppColors.faint,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalHairline() {
    return Container(
      width: 1,
      height: 26,
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
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final h = size.height;
    final w = size.width;

    path.moveTo(0, h * 0.5);
    path.lineTo(w * 0.20, h * 0.5);
    path.lineTo(w * 0.25, h * 0.40);
    path.lineTo(w * 0.30, h * 0.5);
    path.lineTo(w * 0.42, h * 0.5);
    path.lineTo(w * 0.46, h * 0.85);
    path.lineTo(w * 0.52, h * 0.05);
    path.lineTo(w * 0.58, h * 0.70);
    path.lineTo(w * 0.64, h * 0.5);
    path.lineTo(w * 0.76, h * 0.35);
    path.lineTo(w * 0.86, h * 0.5);
    path.lineTo(w, h * 0.5);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
