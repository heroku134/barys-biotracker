import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class CircaBandRadar extends StatefulWidget {
  final double size;
  final bool isScanning;
  final bool isConnected;

  const CircaBandRadar({
    super.key,
    this.size = 220,
    this.isScanning = true,
    this.isConnected = false,
  });

  @override
  State<CircaBandRadar> createState() => _CircaBandRadarState();
}

class _CircaBandRadarState extends State<CircaBandRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _CircaBandRadarPainter(
            progress: widget.isScanning ? _controller.value : 0.0,
            isConnected: widget.isConnected,
          ),
        );
      },
    );
  }
}

class _CircaBandRadarPainter extends CustomPainter {
  final double progress;
  final bool isConnected;

  _CircaBandRadarPainter({
    required this.progress,
    required this.isConnected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxRadius = math.min(cx, cy) - 12;
    final minRadius = 42.0;

    // 1. Отрисовка 3 расходящихся волн радара
    if (progress > 0) {
      for (int i = 0; i < 3; i++) {
        final waveProgress = (progress + (i * 0.33)) % 1.0;
        final radius = minRadius + (maxRadius - minRadius) * waveProgress;
        final alpha = (1.0 - waveProgress) * 0.6;

        final wavePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = (isConnected ? AppColors.sage : AppColors.amber).withValues(alpha: alpha);

        canvas.drawCircle(Offset(cx, cy), radius, wavePaint);
      }
    }

    // 2. Фоновые статические орбиты
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppColors.faint.withValues(alpha: 0.25);

    canvas.drawCircle(Offset(cx, cy), minRadius + 20, orbitPaint);
    canvas.drawCircle(Offset(cx, cy), minRadius + 55, orbitPaint);

    // 3. Центральный корпус титанового браслета CIRCA One
    final bandRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: 68,
      height: 68,
    );

    // Тень и свечение
    final glowPaint = Paint()
      ..color = (isConnected ? AppColors.sage : AppColors.amber).withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawRRect(RRect.fromRectAndRadius(bandRect, const Radius.circular(20)), glowPaint);

    // Заливка корпуса (Титановый обсидиан)
    final bodyPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(bandRect, const Radius.circular(20)), bodyPaint);

    // Окантовка корпуса
    final strokePaint = Paint()
      ..color = isConnected ? AppColors.sage : AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(RRect.fromRectAndRadius(bandRect, const Radius.circular(20)), strokePaint);

    // Золотая акцентная насечка (Nordic Gold)
    final goldPaint = Paint()
      ..color = AppColors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(
      bandRect.deflate(6),
      -math.pi / 4,
      math.pi / 2,
      false,
      goldPaint,
    );

    // 4. Центральный биометрический LED-индикатор
    final ledColor = isConnected ? AppColors.sage : AppColors.amber;
    final ledGlow = Paint()
      ..color = ledColor.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(cx, cy), 6, ledGlow);

    final ledPaint = Paint()
      ..color = ledColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 4.5, ledPaint);
  }

  @override
  bool shouldRepaint(covariant _CircaBandRadarPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isConnected != isConnected;
  }
}
