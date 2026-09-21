import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import 'precision_card.dart';

/// Live heart rate card with a simple vector line waveform (Whoop 5.0 / Sports watch display)
/// - Crisp 1.5px stroke path in muted rose-red (#D14949)
/// - Strictly NO glow, NO gradient fills beneath, NO blur
/// - Hero tabular BPM figure
/// - Monospace stats and live indicator
class PrecisionPulseWave extends StatefulWidget {
  final int bpm;
  final int restingBpm;
  final int peakBpm;
  final VoidCallback? onTap;

  const PrecisionPulseWave({
    super.key,
    required this.bpm,
    this.restingBpm = 52,
    this.peakBpm = 148,
    this.onTap,
  });

  @override
  State<PrecisionPulseWave> createState() => _PrecisionPulseWaveState();
}

class _PrecisionPulseWaveState extends State<PrecisionPulseWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _calculateDuration(widget.bpm),
    )..repeat();
  }

  Duration _calculateDuration(int bpm) {
    final ms = (120000 / bpm.clamp(40, 220)).round().clamp(600, 1600);
    return Duration(milliseconds: ms);
  }

  @override
  void didUpdateWidget(covariant PrecisionPulseWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bpm != widget.bpm) {
      _controller.duration = _calculateDuration(widget.bpm);
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrecisionCard(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Monospace Title & Live Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE HEART RATE',
                style: AppTypography.monoLabel,
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.rose,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 5),
                  Text(
                    'STREAMING',
                    style: AppTypography.monoBadge.copyWith(
                      color: AppColors.rose,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 12),

          // 2. Hero Metric & Extremes
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${widget.bpm}',
                style: AppTypography.heroNumberMedium.copyWith(
                  color: AppColors.rose,
                  fontSize: 36,
                ),
              ),
              SizedBox(width: 6),
              Text(
                'BPM',
                style: AppTypography.monoUnit.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        'REST  ',
                        style: AppTypography.monoLabel.copyWith(
                          fontSize: 9,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '${widget.restingBpm}',
                        style: AppTypography.metricValue.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'PEAK  ',
                        style: AppTypography.monoLabel.copyWith(
                          fontSize: 9,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '${widget.peakBpm}',
                        style: AppTypography.metricValue.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 16),

          // 3. Simple Vector Line Waveform (No glow, no gradients, pure 1.5px stroke)
          SizedBox(
            height: 52,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _PrecisionOscilloscopePainter(
                    phase: _controller.value,
                    lineColor: AppColors.rose,
                    gridColor: AppColors.hairline,
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

class _PrecisionOscilloscopePainter extends CustomPainter {
  final double phase;
  final Color lineColor;
  final Color gridColor;

  _PrecisionOscilloscopePainter({
    required this.phase,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Subtle hairline grid line (baseline)
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, h * 0.5), Offset(w, h * 0.5), gridPaint);

    // 2. Crisp single line waveform (NO fill, NO blur, NO glow)
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    const pointsCount = 100;

    for (int i = 0; i <= pointsCount; i++) {
      final x = (i / pointsCount) * w;
      final cycle = ((i / pointsCount) * 2.5 - phase * 2.0) % 1.0;

      // Realistic ECG waveform profile (P-wave, QRS spike, T-wave)
      double signal = 0.0;
      if (cycle >= 0.15 && cycle < 0.25) {
        // P-wave
        signal = 0.15 * math.sin((cycle - 0.15) * 10 * math.pi);
      } else if (cycle >= 0.28 && cycle < 0.30) {
        // Q dip
        signal = -0.15;
      } else if (cycle >= 0.30 && cycle < 0.34) {
        // R high spike
        final t = (cycle - 0.30) / 0.04;
        signal = 0.95 * (1.0 - (2 * (t - 0.5)).abs());
      } else if (cycle >= 0.34 && cycle < 0.37) {
        // S dip
        signal = -0.25;
      } else if (cycle >= 0.45 && cycle < 0.65) {
        // T-wave
        signal = 0.28 * math.sin((cycle - 0.45) * 5 * math.pi);
      }

      final y = h * 0.5 - (signal * (h * 0.42));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _PrecisionOscilloscopePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}
