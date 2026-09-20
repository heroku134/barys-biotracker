import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

/// Аналоговый Film-Grain фон в стиле Leica M и Bang & Olufsen.
/// Превращает плоскую заливку обсидиана (#050506) в физическую, бархатную поверхность
/// высокоточного премиального прибора.
class CircaFilmGrainBackground extends StatelessWidget {
  final Widget? child;

  const CircaFilmGrainBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Базовый благородный титаново-графитовый оттенок
        const ColoredBox(color: AppColors.stage),

        // 2. Аналоговый шум (запеченный в GPU-слой с нулевым оверхедом)
        const RepaintBoundary(
          child: CustomPaint(
            painter: _LeicaFilmGrainPainter(),
          ),
        ),

        // 3. Мягкая атмосферная глубина (теплый янтарно-графитовый градиент)
        IgnorePointer(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.6),
                radius: 1.35,
                colors: [
                  Color.fromRGBO(196, 165, 116, 0.04), // Едва заметный теплый янтарный отсвет KALKAN
                  Colors.transparent,
                  Color.fromRGBO(12, 14, 19, 0.28),    // Мягкое затемнение по краям
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // 4. Контент поверх фона
        ?child,
      ],
    );
  }
}

class _LeicaFilmGrainPainter extends CustomPainter {
  const _LeicaFilmGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final lightGrainPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.035)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.fill;

    final darkGrainPaint = Paint()
      ..color = const Color.fromRGBO(0, 0, 0, 0.060)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.fill;

    // Детерминированный псевдослучайный генератор зерна (без мерцания и затрат CPU)
    // Шаг 3.5 пикселя дает плотность аналоговой пленки ISO 400
    const step = 3.5;
    final cols = (size.width / step).ceil();
    final rows = (size.height / step).ceil();

    final lightPoints = <Offset>[];
    final darkPoints = <Offset>[];

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        // Быстрый целочисленный хэш координат для органичного распределения частиц
        final h = (r * 1597 + c * 38149 + (r ^ c) * 23) & 0x7FFFFFFF;
        final mod = h % 100;

        if (mod < 7) {
          // Светлое серебряное зерно пленки
          final ox = (h % 3) * 0.4;
          final oy = ((h >> 2) % 3) * 0.4;
          lightPoints.add(Offset(c * step + ox, r * step + oy));
        } else if (mod < 14) {
          // Микро-углубление глубокого черного
          final ox = ((h >> 4) % 3) * 0.4;
          final oy = ((h >> 6) % 3) * 0.4;
          darkPoints.add(Offset(c * step + ox, r * step + oy));
        }
      }
    }

    if (darkPoints.isNotEmpty) {
      canvas.drawPoints(ui.PointMode.points, darkPoints, darkGrainPaint);
    }
    if (lightPoints.isNotEmpty) {
      canvas.drawPoints(ui.PointMode.points, lightPoints, lightGrainPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
