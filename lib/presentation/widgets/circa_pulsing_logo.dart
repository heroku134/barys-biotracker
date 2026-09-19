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
    final baseRadius = size.width * 0.38;

    // 1. Первая волна расширяющегося пульсирующего сияния
    final wave1Scale = 1.0 + (progress * 0.35);
    final wave1Alpha = ((1.0 - progress) * 0.45).clamp(0.0, 1.0);
    final wave1Paint = Paint()
      ..color = primaryColor.withValues(alpha: wave1Alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, baseRadius * wave1Scale, wave1Paint);

    // 2. Вторая фазовая волна (сдвиг на 50% фазы)
    final phase2 = (progress + 0.5) % 1.0;
    final wave2Scale = 1.0 + (phase2 * 0.28);
    final wave2Alpha = ((1.0 - phase2) * 0.35).clamp(0.0, 1.0);
    final wave2Paint = Paint()
      ..color = secondaryColor.withValues(alpha: wave2Alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, baseRadius * wave2Scale, wave2Paint);

    // 3. Мягкое радиальное дыхание подложки (Aura Glow)
    final breathPulse = 0.5 + 0.5 * math.sin(progress * 2 * math.pi);
    final auraGradient = RadialGradient(
      colors: [
        primaryColor.withValues(alpha: 0.22 + breathPulse * 0.12),
        secondaryColor.withValues(alpha: 0.08 + breathPulse * 0.06),
        Colors.transparent,
      ],
      stops: const [0.0, 0.65, 1.0],
    );
    final auraPaint = Paint()
      ..shader = auraGradient.createShader(Rect.fromCircle(center: center, radius: baseRadius * 1.3));
    canvas.drawCircle(center, baseRadius * 1.3, auraPaint);

    // 4. Внешний безель цвета обсидиана
    final bezelPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius, bezelPaint);

    // Граница безеля
    final bezelBorderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor.withValues(alpha: 0.8),
          AppColors.line,
          secondaryColor.withValues(alpha: 0.6),
          primaryColor.withValues(alpha: 0.3),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, baseRadius, bezelBorderPaint);

    // 5. 48 высокоточных калибровочных насечек (как на часовом безеле Patek / Leica)
    final notchCount = 48;
    for (int i = 0; i < notchCount; i++) {
      final angle = (i * 2 * math.pi) / notchCount - math.pi / 2;
      final isMajor = i % 4 == 0;
      final isCardinal = i % 12 == 0;

      final notchLen = isCardinal ? 6.5 : (isMajor ? 4.5 : 2.5);
      final notchPaint = Paint()
        ..color = isCardinal
            ? primaryColor
            : (isMajor ? AppColors.fg.withValues(alpha: 0.7) : AppColors.faint)
        ..strokeWidth = isCardinal ? 1.8 : (isMajor ? 1.2 : 0.8)
        ..strokeCap = StrokeCap.round;

      final p1 = Offset(
        center.dx + (baseRadius - 2.5) * math.cos(angle),
        center.dy + (baseRadius - 2.5) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (baseRadius - 2.5 - notchLen) * math.cos(angle),
        center.dy + (baseRadius - 2.5 - notchLen) * math.sin(angle),
      );
      canvas.drawLine(p1, p2, notchPaint);
    }

    // 6. Внутренний золотой контур
    final innerRadius = baseRadius * 0.72;
    final innerRingPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.4 + breathPulse * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, innerRadius, innerRingPaint);

    // 7. Центральная эмблема: стилизованный герб Барыс / Монограмма CIRCA
    _drawCenterBarysEmblem(canvas, center, innerRadius * 0.75, breathPulse);
  }

  void _drawCenterBarysEmblem(Canvas canvas, Offset center, double radius, double pulse) {
    // Центральный золотой треугольный щит с сакскими линиями
    final path = Path();

    // Верхняя корона ушей снежного барса
    final topY = center.dy - radius * 0.75;
    final bottomY = center.dy + radius * 0.75;
    final leftX = center.dx - radius * 0.75;
    final rightX = center.dx + radius * 0.75;

    // Контур морды барса (сакский стиль / скифское золото)
    path.moveTo(center.dx, topY - radius * 0.1);
    path.lineTo(rightX, topY + radius * 0.4);
    path.lineTo(center.dx + radius * 0.35, bottomY);
    path.lineTo(center.dx, bottomY - radius * 0.15);
    path.lineTo(center.dx - radius * 0.35, bottomY);
    path.lineTo(leftX, topY + radius * 0.4);
    path.close();

    final emblemFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha: 0.25),
          AppColors.stage,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, emblemFill);

    final emblemBorder = Paint()
      ..color = primaryColor.withValues(alpha: 0.85 + pulse * 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, emblemBorder);

    // Внутренние сакские геометрические насечки (усы и взгляд барса)
    final eyePaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Глаза барса
    final eyeY = center.dy - radius * 0.1;
    canvas.drawLine(
      Offset(center.dx - radius * 0.4, eyeY - radius * 0.08),
      Offset(center.dx - radius * 0.15, eyeY),
      eyePaint,
    );
    canvas.drawLine(
      Offset(center.dx + radius * 0.4, eyeY - radius * 0.08),
      Offset(center.dx + radius * 0.15, eyeY),
      eyePaint,
    );

    // Центральная точка силы (алмазный кристалл в центре лба)
    final diamondPath = Path();
    final dCenter = Offset(center.dx, center.dy - radius * 0.35);
    final dSize = radius * 0.15;
    diamondPath.moveTo(dCenter.dx, dCenter.dy - dSize);
    diamondPath.lineTo(dCenter.dx + dSize * 0.8, dCenter.dy);
    diamondPath.lineTo(dCenter.dx, dCenter.dy + dSize);
    diamondPath.lineTo(dCenter.dx - dSize * 0.8, dCenter.dy);
    diamondPath.close();

    final diamondPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(diamondPath, diamondPaint);

    // Нижняя надпись монограммы CIRCA
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'CIRCA',
        style: TextStyle(
          color: AppColors.fg,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy + radius * 0.32),
    );
  }

  @override
  bool shouldRepaint(covariant _CircaPulsingLogoPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
