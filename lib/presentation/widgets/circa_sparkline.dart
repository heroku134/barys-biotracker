import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../data/history/biometrics_history_repository.dart';

class CircaSparkline extends StatelessWidget {
  final List<HistoricalPoint> points;
  final double? baselineMin;
  final double? baselineMax;
  final Color lineColor;
  final double height;
  final String unit;

  const CircaSparkline({
    super.key,
    required this.points,
    this.baselineMin,
    this.baselineMax,
    this.lineColor = AppColors.sage,
    this.height = 42,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SparklinePainter(
          points: points,
          baselineMin: baselineMin,
          baselineMax: baselineMax,
          lineColor: lineColor,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<HistoricalPoint> points;
  final double? baselineMin;
  final double? baselineMax;
  final Color lineColor;

  _SparklinePainter({
    required this.points,
    this.baselineMin,
    this.baselineMax,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final values = points.map((p) => p.value).toList();
    var minVal = values.reduce(math.min);
    var maxVal = values.reduce(math.max);

    if (baselineMin != null) minVal = math.min(minVal, baselineMin!);
    if (baselineMax != null) maxVal = math.max(maxVal, baselineMax!);

    final range = (maxVal - minVal) <= 0 ? 1.0 : (maxVal - minVal);
    const padY = 4.0;
    final drawHeight = size.height - (padY * 2);

    double getY(double v) {
      final ratio = (v - minVal) / range;
      return size.height - padY - (ratio * drawHeight);
    }

    double getX(int index) {
      return (index / (points.length - 1)) * size.width;
    }

    // 1. Отрисовка коридора личной нормы (Baseline Tunnel)
    if (baselineMin != null && baselineMax != null) {
      final yTop = getY(baselineMax!);
      final yBottom = getY(baselineMin!);

      final baselinePaint = Paint()
        ..color = lineColor.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTRB(0, yTop, size.width, yBottom),
        baselinePaint,
      );

      final baselineBorder = Paint()
        ..color = lineColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      canvas.drawLine(Offset(0, yTop), Offset(size.width, yTop), baselineBorder);
      canvas.drawLine(Offset(0, yBottom), Offset(size.width, yBottom), baselineBorder);
    }

    // 2. Линия тренда со сглаживанием
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = getX(i);
      final y = getY(points[i].value);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = getX(i - 1);
        final prevY = getY(points[i - 1].value);
        final midX = (prevX + x) / 2;
        path.cubicTo(midX, prevY, midX, y, x, y);
      }
    }

    // Градиентная заливка под графиком
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.22),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Основная линия
    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Точка последнего значения
    final lastX = getX(points.length - 1);
    final lastY = getY(points.last.value);

    final dotPaint = Paint()..color = lineColor;
    final dotGlow = Paint()
      ..color = lineColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(Offset(lastX, lastY), 5, dotGlow);
    canvas.drawCircle(Offset(lastX, lastY), 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}
