import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

/// Богатое пульсирующее лого в часовом стиле высокой точности (Quiet Luxury & Bio-Metric Atelier)
class CircaPulsingLogo extends StatefulWidget {
  final double size;
  final Color primaryColor;
  final Color secondaryColor;
  final bool animate;

  const CircaPulsingLogo({
    super.key,
    this.size = 160.0,
    this.primaryColor = AppColors.amber,
    this.secondaryColor = AppColors.sage,
    this.animate = true,
  });

  @override
  State<CircaPulsingLogo> createState() => _CircaPulsingLogoState();
}

class _CircaPulsingLogoState extends State<CircaPulsingLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(CircaPulsingLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
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
          painter: _CircaPulsingLogoPainter(
            progress: _controller.value,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
          ),
        );
      },
    );
  }
}

class _CircaPulsingLogoPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  _CircaPulsingLogoPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final breathPulse = 0.5 + 0.5 * math.sin(progress * 2 * math.pi);

    // 1. Мягкое радиальное дыхание фоновой ауры (Aura Glow)
    final auraRadius = size.width * 0.46;
    final auraGradient = RadialGradient(
      colors: [
        primaryColor.withValues(alpha: 0.18 + breathPulse * 0.10),
        secondaryColor.withValues(alpha: 0.07 + breathPulse * 0.05),
        Colors.transparent,
      ],
      stops: const [0.0, 0.60, 1.0],
    );
    final auraPaint = Paint()
      ..shader = auraGradient.createShader(Rect.fromCircle(center: center, radius: auraRadius));
    canvas.drawCircle(center, auraRadius, auraPaint);

    // 2. Чистая центральная эмблема KALKAN без часовых циферблатов и насечек
    final emblemWidth = size.width * 0.82;
    _drawCenterKalkanEmblem(canvas, center, emblemWidth, breathPulse);
  }

  void _drawCenterKalkanEmblem(Canvas canvas, Offset center, double emblemWidth, double pulse) {
    // Масштабирование координат оригинального вектора KALKAN
    // Размах вектора ~ 286x125, центр ~ (182, 134)
    final scale = emblemWidth / 286;
    final ox = center.dx - 182 * scale;
    final oy = center.dy - 134 * scale;

    // 1. Верхний парящий серп (Golden Amber & Sage)
    final topArc = Path();
    topArc.moveTo(ox + 39 * scale, oy + 165 * scale);
    topArc.cubicTo(
      ox + 77 * scale, oy + 72 * scale,
      ox + 209 * scale, oy + 90 * scale,
      ox + 295 * scale, oy + 143 * scale,
    );
    topArc.cubicTo(
      ox + 189 * scale, oy + 104 * scale,
      ox + 118 * scale, oy + 120 * scale,
      ox + 39 * scale, oy + 165 * scale,
    );
    topArc.close();

    // Легкое свечение верхнего серпа
    final topGlowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.25 + pulse * 0.15)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(topArc, topGlowPaint);

    final topPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor,
          secondaryColor,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: emblemWidth / 2))
      ..style = PaintingStyle.fill;
    canvas.drawPath(topArc, topPaint);

    // 2. Нижняя парящая дуга (Titanium / Crisp White)
    final bottomArc = Path();
    bottomArc.moveTo(ox + 52 * scale, oy + 195 * scale);
    bottomArc.cubicTo(
      ox + 130 * scale, oy + 103 * scale,
      ox + 247 * scale, oy + 103 * scale,
      ox + 325 * scale, oy + 195 * scale,
    );

    // Легкое свечение нижней дуги
    final bottomGlowPaint = Paint()
      ..color = AppColors.fg.withValues(alpha: 0.20 + pulse * 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(bottomArc, bottomGlowPaint);

    final bottomPaint = Paint()
      ..color = AppColors.fg.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.5 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(bottomArc, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant _CircaPulsingLogoPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
