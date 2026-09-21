import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';

class MetricDial extends StatelessWidget {
  final String label;
  final String value;
  final double progress; // 0..1
  final Color color;
  final VoidCallback? onTap;
  final double size;

  const MetricDial({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
    this.onTap,
    this.size = 104,
  });

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _DialPainter(
                progress: progress.clamp(0.0, 1.0),
                color: color,
                track: palette.hairline,
              ),
              child: Center(
                child: Text(
                  value,
                  style: AppTypography.heroNumberMedium(palette.fg).copyWith(fontSize: 26),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTypography.caption(palette.secondary).copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;

  _DialPainter({required this.progress, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 5;
    const start = -math.pi / 2;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, trackPaint);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, 2 * math.pi * progress, false, valuePaint);
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}
