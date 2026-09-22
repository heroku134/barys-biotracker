import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class LivePulseWaveWidget extends StatefulWidget {
  final int bpm;
  final double height;

  const LivePulseWaveWidget({
    super.key,
    required this.bpm,
    this.height = 70,
  });

  @override
  State<LivePulseWaveWidget> createState() => _LivePulseWaveWidgetState();
}

class _LivePulseWaveWidgetState extends State<LivePulseWaveWidget>
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
    final ms = (120000 / bpm.clamp(40, 220)).round().clamp(500, 1800);
    return Duration(milliseconds: ms);
  }

  @override
  void didUpdateWidget(covariant LivePulseWaveWidget oldWidget) {
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

  Color _getZoneColor(int bpm) {
    if (bpm < 90) return AppColors.sage;
    if (bpm < 130) return AppColors.amber;
    return AppColors.rose;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getZoneColor(widget.bpm);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(
            painter: _PulseWavePainter(
              phase: _controller.value,
              waveColor: color,
            ),
          ),
        );
      },
    );
  }
}

class _PulseWavePainter extends CustomPainter {
  final double phase;
  final Color waveColor;

  _PulseWavePainter({
    required this.phase,
    required this.waveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h * 0.55;

    final path = Path();
    final fillPath = Path();

    const pointsCount = 120;
    var started = false;

    for (var i = 0; i <= pointsCount; i++) {
      final x = (i / pointsCount) * w;
      // Смещение волны
      final cycle = ((i / pointsCount) + phase) % 1.0;

      double ecgOffset = 0.0;
      // Моделирование сердечного P-Q-R-S-T комплекса
      if (cycle >= 0.40 && cycle < 0.46) {
        // P-волна (предсердия)
        ecgOffset = -math.sin((cycle - 0.40) / 0.06 * math.pi) * (h * 0.15);
      } else if (cycle >= 0.47 && cycle < 0.50) {
        // Q-зубец (небольшой спад)
        ecgOffset = ((cycle - 0.47) / 0.03) * (h * 0.12);
      } else if (cycle >= 0.50 && cycle < 0.54) {
        // R-пик (мощный всплеск вверх)
        final p = (cycle - 0.50) / 0.04;
        ecgOffset = -math.sin(p * math.pi) * (h * 0.48);
      } else if (cycle >= 0.54 && cycle < 0.57) {
        // S-зубец (глубокий спад)
        ecgOffset = math.sin((cycle - 0.54) / 0.03 * math.pi) * (h * 0.18);
      } else if (cycle >= 0.62 && cycle < 0.72) {
        // T-волна (реполяризация)
        ecgOffset = -math.sin((cycle - 0.62) / 0.10 * math.pi) * (h * 0.22);
      }

      final y = (midY + ecgOffset).clamp(4.0, h - 4.0);

      if (!started) {
        path.moveTo(x, y);
        fillPath.moveTo(x, h);
        fillPath.lineTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(w, h);
    fillPath.close();

    // Градиентная заливка под волной
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        waveColor.withValues(alpha: 0.25),
        waveColor.withValues(alpha: 0.0),
      ],
    );
    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    if (waveColor.computeLuminance() < 0.4) {
      final glowPaint = Paint()
        ..color = waveColor.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawPath(path, glowPaint);
    }

    // Четкая основная линия волны
    final linePaint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _PulseWavePainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.waveColor != waveColor;
  }
}
