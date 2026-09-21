import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/circa_haptics.dart';
import '../../domain/models/readiness.dart';

class CircaReadinessRing extends StatefulWidget {
  final int score;
  final RecoveryZone zone;
  final double size;

  const CircaReadinessRing({
    super.key,
    required this.score,
    required this.zone,
    this.size = 190,
  });

  @override
  State<CircaReadinessRing> createState() => _CircaReadinessRingState();
}

class _CircaReadinessRingState extends State<CircaReadinessRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;
  bool _hitRoseZone = false;
  bool _hitAmberZone = false;

  @override
  void initState() {
    super.initState();
    // 1.2 сек кинематографичного дозаполнения (утренний unboxing в стиле Duolingo)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnim = Tween<double>(
      begin: 0.0,
      end: widget.score / 100.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Микро-вибрация Apple Haptic при пересечении зон восстановления
    _controller.addListener(() {
      final currentScore = (widget.score * _controller.value).round();
      if (currentScore >= 33 && !_hitRoseZone) {
        _hitRoseZone = true;
        CircaHaptics.ringZoneTick();
      }
      if (currentScore >= 66 && !_hitAmberZone) {
        _hitAmberZone = true;
        CircaHaptics.ringZoneTick();
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Финальный глубокий щелчок закрытия кольца с механическим звуком
        CircaHaptics.ringClosure();
      }
    });

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant CircaReadinessRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _hitRoseZone = false;
      _hitAmberZone = false;
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _CircaRingPainter(
              progress: _progressAnim.value,
              score: (widget.score * _controller.value).round(),
              zone: widget.zone,
            ),
          ),
        );
      },
    );
  }
}

class _CircaRingPainter extends CustomPainter {
  final double progress;
  final int score;
  final RecoveryZone zone;

  _CircaRingPainter({
    required this.progress,
    required this.score,
    required this.zone,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 12;
    const strokeWidth = 9.0;

    // 1. Фоновый трек кольца (#181A21 raised)
    final trackPaint = Paint()
      ..color = AppColors.raised
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Цвет зоны: строго однотонный без радужных переливов
    final Color solidZoneColor;
    switch (zone) {
      case RecoveryZone.optimal:
        solidZoneColor = AppColors.sage;
        break;
      case RecoveryZone.moderate:
        solidZoneColor = AppColors.amber;
        break;
      case RecoveryZone.recovery:
        solidZoneColor = AppColors.rose;
        break;
    }

    // 2. Деликатное свечение дуги
    final glowPaint = Paint()
      ..color = solidZoneColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // 3. Основная дуга прогресса (однотонная)
    final progressPaint = Paint()
      ..color = solidZoneColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        glowPaint,
      );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }

    // 4. Цифра Score (Display tabular figures со сжатым трекингом)
    final scorePainter = TextPainter(
      text: TextSpan(
        text: '$score',
        style: TextStyle(
          color: AppColors.fg,
          fontSize: 54,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
          letterSpacing: -1.5,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    scorePainter.paint(
      canvas,
      Offset(center.dx - scorePainter.width / 2, center.dy - scorePainter.height / 2 - 10),
    );

    // 5. Подпись ВОССТАНОВЛЕНИЕ (строгий CAPS, 12, letterSpacing 2.0)
    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'ВОССТАНОВЛЕНИЕ',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    labelPainter.paint(
      canvas,
      Offset(center.dx - labelPainter.width / 2, center.dy + 26),
    );
  }

  @override
  bool shouldRepaint(covariant _CircaRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.score != score ||
        oldDelegate.zone != zone;
  }
}
