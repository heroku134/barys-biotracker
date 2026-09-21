import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../domain/models/readiness.dart';
import '../../domain/models/telemetry.dart';

/// Высокопрецизионная карточка для Instagram Stories / Telegram (пропорции 9:16, 1080x1920)
class StoriesCardWidget extends StatelessWidget {
  final BleTelemetry telemetry;
  final ReadinessResult readiness;
  final double currentStrain;
  final String? photoPath;
  final String athleteName;
  final String athleteTier;

  const StoriesCardWidget({
    super.key,
    required this.telemetry,
    required this.readiness,
    required this.currentStrain,
    this.photoPath,
    this.athleteName = 'КАНАТ АМАНОВ',
    this.athleteTier = 'BATYR ELITE · TIER I',
  });

  Color get _zoneColor {
    if (readiness.score >= 67) return AppColors.sage;
    if (readiness.score >= 34) return AppColors.amber;
    return AppColors.rose;
  }

  String get _zoneLabel {
    if (readiness.score >= 67) return 'OPTIMAL · GREEN ZONE';
    if (readiness.score >= 34) return 'MODERATE · STRAIN ADVISORY';
    return 'RESTORATION · LOW CAPACITY';
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.obsidian,
          border: Border.all(color: AppColors.hairline, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. ФОНОВЫЙ СЛОЙ (Фото Дня или Градиентный Обсидиан)
            if (photoPath != null && File(photoPath!).existsSync())
              Image.file(
                File(photoPath!),
                fit: BoxFit.cover,
              )
            else
              Image.asset(
                'assets/images/landmarks/ala_too.jpg',
                fit: BoxFit.cover,
              ),

            // Кинематографическое затемнение для читаемости лазерного HUD
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.black.withValues(alpha: 0.40),
                    Colors.black.withValues(alpha: 0.90),
                    Colors.black.withValues(alpha: 0.98),
                  ],
                  stops: const [0.0, 0.35, 0.70, 1.0],
                ),
              ),
            ),

            // 2. КОНТЕНТ HUD (9:16 Precision Layer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ВЕРХНЯЯ ШАПКА
                  _buildHeader(),

                  // ЦЕНТРАЛЬНЫЙ БЛОК: HERO RECOVERY GAUGE
                  _buildHeroRecovery(),

                  // НИЖНИЙ БЛОК: 4 ПРЕЦИЗИОННЫХ БИОМАРКЕРА + БРЕНДИНГ
                  Column(
                    children: [
                      _buildMetricsGrid(),
                      const SizedBox(height: 24),
                      _buildFooter(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _zoneColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'KALKAN SPORT · SAAT-1',
                style: AppTypography.monoLabel.copyWith(
                  color: AppColors.textNearWhite,
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            athleteTier,
            style: AppTypography.monoLabel.copyWith(
              color: AppColors.amber,
              fontSize: 9,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroRecovery() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Прецизионный моноширинный заголовок
          Text(
            'BIOMETRIC RECOVERY',
            style: AppTypography.monoLabel.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Гигантское круговое кольцо готовности
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 148,
                height: 148,
                child: CircularProgressIndicator(
                  value: readiness.score / 100.0,
                  strokeWidth: 9,
                  backgroundColor: AppColors.raised,
                  valueColor: AlwaysStoppedAnimation<Color>(_zoneColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${readiness.score}',
                        style: const TextStyle(
                          color: AppColors.textNearWhite,
                          fontSize: 54,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '%',
                          style: AppTypography.monoLabel.copyWith(
                            color: AppColors.muted,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'RECOVERY',
                    style: AppTypography.monoLabel.copyWith(
                      color: _zoneColor,
                      fontSize: 8.5,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Статус зоны
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _zoneColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _zoneColor.withValues(alpha: 0.4), width: 1.0),
            ),
            child: Text(
              _zoneLabel,
              style: AppTypography.monoBadge.copyWith(
                color: _zoneColor,
                fontSize: 9.5,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'DAY STRAIN',
                value: currentStrain.toStringAsFixed(1),
                unit: '/ 21.0',
                accent: AppColors.amber,
                subtext: 'OPTIMAL LOAD',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'RESTING HR',
                value: '${telemetry.restingHeartRate > 0 ? telemetry.restingHeartRate : 52}',
                unit: 'BPM',
                accent: AppColors.rose,
                subtext: 'NADIR IN DEEP SLEEP',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'BIO-AGE ADVANTAGE',
                value: '-4',
                unit: 'YRS',
                accent: AppColors.sage,
                subtext: 'BIO 24 · CHRONO 28',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'HRV rMSSD',
                value: '${telemetry.hrv.round()}',
                unit: 'MS',
                accent: AppColors.textNearWhite,
                subtext: 'BASELINE: 64 MS',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String unit,
    required Color accent,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.monoLabel.copyWith(
              color: AppColors.textSecondary,
              fontSize: 8.5,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: AppTypography.monoLabel.copyWith(
                  color: AppColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: AppTypography.monoLabel.copyWith(
              color: AppColors.muted,
              fontSize: 7.5,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.raised.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/kalkan_app_icon_1024.png',
                width: 22,
                height: 22,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    athleteName,
                    style: const TextStyle(
                      color: AppColors.textNearWhite,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'VERIFIED ATHLETIC TELEMETRY',
                    style: AppTypography.monoLabel.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 7.5,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            '#KALKANSPORT',
            style: AppTypography.monoLabel.copyWith(
              color: AppColors.amber,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
