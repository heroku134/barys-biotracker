import 'package:flutter/material.dart';

/// Виджет мягкого затухания по краям (Edge Fade) для горизонтальных скролл-списков и чипов
/// Устраняет резкую обрезку элементов у границы экрана, создавая премиальный аналоговый градиент.
class CircaEdgeFade extends StatelessWidget {
  final Widget child;
  final double fadeWidthFraction;

  const CircaEdgeFade({
    super.key,
    required this.child,
    this.fadeWidthFraction = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [
            0.0,
            fadeWidthFraction,
            1.0 - fadeWidthFraction,
            1.0,
          ],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
