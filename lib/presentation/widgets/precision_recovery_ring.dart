import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../domain/models/readiness.dart';

/// Large circular recovery ring (Whoop 5.0 / Oura Athletic precision)
/// - Clean vector arc with NO glow, NO blur, NO gradients
/// - Hero tabular figure in geometric grotesk (w600)
/// - Monospace labels and units
class PrecisionRecoveryRing extends StatefulWidget {
  final int score;
  final RecoveryZone zone;
  final double hrv;
  final int restingHeartRate;
  final double skinTempDeviation;
  final double size;
  final VoidCallback? onTap;

  const PrecisionRecoveryRing({
    super.key,
    required this.score,
    required this.zone,
    this.hrv = 64.0,
    this.restingHeartRate = 52,
    this.skinTempDeviation = 0.2,
    this.size = 210,
    this.onTap,
  });

  @override
  State<PrecisionRecoveryRing> createState() => _PrecisionRecoveryRingState();
}

class _PrecisionRecoveryRingState extends State<PrecisionRecoveryRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnim = Tween<double>(
      begin: 0.0,
      end: widget.score / 100.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant PrecisionRecoveryRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _progressAnim = Tween<double>(
        begin: _progressAnim.value,
        end: widget.score / 100.0,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _zoneColor {
    switch (widget.zone) {
      case RecoveryZone.optimal:
        return AppColors.sage;
      case RecoveryZone.moderate:
        return AppColors.amber;
      case RecoveryZone.recovery:
        return AppColors.rose;
    }
  }

  String get _zoneLabel {
    switch (widget.zone) {
      case RecoveryZone.optimal:
        return 'OPTIMAL';
      case RecoveryZone.moderate:
        return 'MODERATE';
      case RecoveryZone.recovery:
        return 'REDUCED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Circular Ring with Hero Score
        GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _progressAnim,
            builder: (context, child) {
              final animatedScore = (widget.score * _controller.value).round();
              return SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Precise Vector Arc (0 glow, 0 blur)
                    CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _PrecisionRingPainter(
                        progress: _progressAnim.value,
                        ringColor: _zoneColor,
                        trackColor: AppColors.raised,
                      ),
                    ),
                    // Inner Metric Block
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'RECOVERY',
                          style: AppTypography.monoLabel.copyWith(
                            fontSize: 10,
                            letterSpacing: 2.0,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '$animatedScore',
                          style: AppTypography.heroNumber.copyWith(
                            color: AppColors.textNearWhite,
                            fontSize: widget.size * 0.28,
                          ),
                        ),
                        SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '/ 100  ·  ',
                              style: AppTypography.monoUnit.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              _zoneLabel,
                              style: AppTypography.monoBadge.copyWith(
                                color: _zoneColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        SizedBox(height: 20),

        // 2. Strict 3-Column Metric Grid with 1px hairline dividers
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.hairline, width: 1.0),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildSubMetric(
                  label: 'HRV',
                  value: '${widget.hrv.round()}',
                  unit: 'MS',
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.hairline),
              Expanded(
                child: _buildSubMetric(
                  label: 'REST HR',
                  value: '${widget.restingHeartRate}',
                  unit: 'BPM',
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.hairline),
              Expanded(
                child: _buildSubMetric(
                  label: 'SKIN TEMP',
                  value: '${widget.skinTempDeviation >= 0 ? '+' : ''}${widget.skinTempDeviation.toStringAsFixed(1)}',
                  unit: '°C',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubMetric({
    required String label,
    required String value,
    required String unit,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.monoLabel.copyWith(
            fontSize: 9.5,
            letterSpacing: 1.2,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppTypography.metricValue.copyWith(
                color: AppColors.textNearWhite,
                fontSize: 16,
              ),
            ),
            SizedBox(width: 3),
            Text(
              unit,
              style: AppTypography.monoUnit.copyWith(
                fontSize: 9.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PrecisionRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;

  _PrecisionRingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const strokeWidth = 7.0;

    // 1. Crisp Background Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Active Score Arc (strictly NO blur, NO glow)
    if (progress > 0) {
      final activePaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PrecisionRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.trackColor != trackColor;
  }
}
