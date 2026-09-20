import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

/// Живая дышащая биометрическая ретина CIRCA ONE
/// Реализует респираторный цикл дыхания 4.8 сек (вдох/выдох)
/// с оптической апертурой, калибровочными микро-метками и пульсирующим зрачком.
class CircaBreathingRetina extends StatefulWidget {
  final double size;
  final bool isScanning;
  final Color? accentColor;

  const CircaBreathingRetina({
    super.key,
    this.size = 150,
    this.isScanning = true,
    this.accentColor,
  });

  @override
  State<CircaBreathingRetina> createState() => _CircaBreathingRetinaState();
}

class _CircaBreathingRetinaState extends State<CircaBreathingRetina>
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final Animation<double> _breathAnimation;

  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();

    // Медленный респираторный цикл дыхания: 4.8 сек (2.4с вдох, 2.4с выдох)
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat(reverse: true);

    _breathAnimation = CurvedAnimation(
      parent: _breathController,
      curve: Curves.easeInOutSine,
    );

    // Медленное вращение оптической калибровочной сетки: 36 сек
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 36),
    )..repeat();
  }

  @override
  void dispose() {
    _breathController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ?? AppColors.sage;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_breathAnimation, _rotationController]),
          builder: (context, child) {
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _BreathingRetinaPainter(
                breath: _breathAnimation.value,
                rotation: _rotationController.value * 2 * math.pi,
                accentColor: color,
                isScanning: widget.isScanning,
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        // Микро-подпись о живом био-ритме
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'ДЫХАТЕЛЬНЫЙ РИТМ 4.8s · БИОСИСТЕМА ЖИВАЯ',
              style: TextStyle(
                color: AppColors.muted.withValues(alpha: 0.8),
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BreathingRetinaPainter extends CustomPainter {
  final double breath; // 0.0 (выдох) .. 1.0 (вдох)
  final double rotation;
  final Color accentColor;
  final bool isScanning;

  _BreathingRetinaPainter({
    required this.breath,
    required this.rotation,
    required this.accentColor,
    required this.isScanning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final maxR = size.width / 2;

    // 1. Внешняя дышащая био-аура (Glow halo)
    final auraRadius = (maxR - 8) + (breath * 10);
    final auraAlpha = 0.15 + (breath * 0.25);
    final auraPaint = Paint()
      ..color = accentColor.withValues(alpha: auraAlpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 + (breath * 10));
    canvas.drawCircle(center, auraRadius, auraPaint);

    // 2. Внешнее калибровочное кольцо с 48 оптическими насечками
    final outerRingR = maxR - 10;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppColors.line.withValues(alpha: 0.6);
    canvas.drawCircle(center, outerRingR, ringPaint);

    const int tickCount = 48;
    for (int i = 0; i < tickCount; i++) {
      final angle = (i * (2 * math.pi / tickCount)) + (rotation * 0.25);
      final isMajor = i % 6 == 0;
      final tickLen = isMajor ? 5.0 : 2.5;
      final startR = outerRingR - tickLen;
      final endR = outerRingR;

      final p1 = Offset(cx + startR * math.cos(angle), cy + startR * math.sin(angle));
      final p2 = Offset(cx + endR * math.cos(angle), cy + endR * math.sin(angle));

      final tickPaint = Paint()
        ..color = isMajor
            ? accentColor.withValues(alpha: 0.7)
            : AppColors.muted.withValues(alpha: 0.3)
        ..strokeWidth = isMajor ? 1.2 : 0.8;

      canvas.drawLine(p1, p2, tickPaint);
    }

    // 3. Среднее оптическое кольцо диафрагмы (Iris aperture ring)
    final irisR = (outerRingR - 16) + (breath * 4.0);
    final irisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accentColor.withValues(alpha: 0.35 + (breath * 0.25));
    canvas.drawCircle(center, irisR, irisPaint);

    // 4. Лепестки оптической диафрагмы ретины (8 дуг)
    const int bladeCount = 8;
    for (int i = 0; i < bladeCount; i++) {
      final bladeAngle = (i * (2 * math.pi / bladeCount)) + rotation;
      final bladeStartR = 24.0 + (breath * 6.0);
      final bladeEndR = irisR - 2;

      final pStart = Offset(
        cx + bladeStartR * math.cos(bladeAngle),
        cy + bladeStartR * math.sin(bladeAngle),
      );
      final pEnd = Offset(
        cx + bladeEndR * math.cos(bladeAngle + 0.4),
        cy + bladeEndR * math.sin(bladeAngle + 0.4),
      );

      final bladePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.22 + (breath * 0.18))
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(pStart, pEnd, bladePaint);
    }

    // 5. Корпус био-сенсора CIRCA
    final sensorR = 26.0 + (breath * 2.5);
    final sensorBodyPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, sensorR, sensorBodyPaint);

    final sensorBorderPaint = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, sensorR, sensorBorderPaint);

    // 6. Золотая акцентная дуга на корпусе сенсора (Nordic Gold hairline)
    final goldArcPaint = Paint()
      ..color = AppColors.amber.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: sensorR - 2),
      -math.pi / 3 + (rotation * 1.5),
      math.pi / 2,
      false,
      goldArcPaint,
    );

    // 7. Центральный пульсирующий зрачок (Pupil / Core Bio-Emitter)
    final pupilR = 7.0 + (breath * 4.0); // Зрачок сужается и расширяется при дыхании!

    // Ореол зрачка
    final pupilGlowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.6 + (breath * 0.35))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, pupilR + 2, pupilGlowPaint);

    // Тело зрачка
    final pupilPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, pupilR, pupilPaint);

    // Белая точка блика в центре зрачка (глянец живого глаза)
    final glintPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(cx - (pupilR * 0.28), cy - (pupilR * 0.28)),
      pupilR * 0.28,
      glintPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BreathingRetinaPainter oldDelegate) {
    return oldDelegate.breath != breath ||
        oldDelegate.rotation != rotation ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isScanning != isScanning;
  }
}
