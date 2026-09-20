import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/circa_haptics.dart';
import '../../domain/models/readiness.dart';

/// Высокотехнологичная 3D-сфера готовности ЦНС и восстановления (Volumetric Biometric Orb)
/// Создает эффект объемного светящегося биометрического шара с физической глубиной,
/// световыми бликами, внешним ореолом и живым дыханием.
class Circa3DRecoveryOrb extends StatefulWidget {
  final int score;
  final RecoveryZone zone;
  final double size;
  final VoidCallback? onTap;

  const Circa3DRecoveryOrb({
    super.key,
    required this.score,
    required this.zone,
    this.size = 210,
    this.onTap,
  });

  @override
  State<Circa3DRecoveryOrb> createState() => _Circa3DRecoveryOrbState();
}

class _Circa3DRecoveryOrbState extends State<Circa3DRecoveryOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.025).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _animController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orbSize = widget.size;
    final primaryColor = widget.zone.color;

    return GestureDetector(
      onTap: () {
        CircaHaptics.ringZoneTick();
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final scale = _pulseAnimation.value;

          return SizedBox(
            width: orbSize,
            height: orbSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Мягкая нижняя контактная тень на поверхности карточки
                Positioned(
                  bottom: orbSize * 0.04,
                  child: Container(
                    width: orbSize * 0.72,
                    height: orbSize * 0.16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(orbSize * 0.72, orbSize * 0.16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 24,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Внешняя биометрическая аура (атмосферное дыхание)
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: orbSize * 0.88,
                    height: orbSize * 0.88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.32),
                          blurRadius: 36,
                          spreadRadius: 8,
                        ),
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.15),
                          blurRadius: 60,
                          spreadRadius: 18,
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Тонкое внешнее орбитальное кольцо с делениями (Швейцарская прецизионность)
                CustomPaint(
                  size: Size(orbSize * 0.96, orbSize * 0.96),
                  painter: _OrbitalRingPainter(
                    color: primaryColor.withValues(alpha: 0.45),
                    rotation: _rotationAnimation.value * 0.2,
                  ),
                ),

                // 4. Объемное 3D-тело сферы с градиентным освещением (источник света сверху слева)
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: orbSize * 0.82,
                    height: orbSize * 0.82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.38, -0.42),
                        radius: 0.85,
                        colors: [
                          Color.lerp(Colors.white, primaryColor, 0.35)!,
                          primaryColor,
                          Color.lerp(primaryColor, Colors.black, 0.45)!,
                          Color.lerp(primaryColor, Colors.black, 0.82)!,
                          const Color(0xFF080B0F),
                        ],
                        stops: const [0.0, 0.35, 0.65, 0.88, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.65),
                          blurRadius: 16,
                          offset: const Offset(4, 8),
                        ),
                      ],
                    ),
                  ),
                ),

                // 5. Внутренний линзовый блик (Стеклянная линза в стиле Apple / luxury optic)
                Positioned(
                  top: orbSize * 0.14,
                  left: orbSize * 0.22,
                  child: Container(
                    width: orbSize * 0.38,
                    height: orbSize * 0.22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(orbSize * 0.38, orbSize * 0.22),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // 6. Нижний краевой контурный рефлекс (Rim light)
                Positioned(
                  bottom: orbSize * 0.13,
                  child: Container(
                    width: orbSize * 0.48,
                    height: orbSize * 0.08,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(orbSize * 0.48, orbSize * 0.08),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          primaryColor.withValues(alpha: 0.35),
                          primaryColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // 7. Центральный контент: крупный показатель готовности и статус
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Числовое значение готовности (94)
                    Text(
                      '${widget.score}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                        height: 1.0,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Подпись под показателем
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryColor,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor,
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'ВОССТАНОВЛЕНИЕ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Отрисовка тонкого космическо-часового кольца вокруг сферы
class _OrbitalRingPainter extends CustomPainter {
  final Color color;
  final double rotation;

  _OrbitalRingPainter({required this.color, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius, ringPaint);

    // Рисование деликатных маркеров на окружности
    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const tickCount = 24;
    for (var i = 0; i < tickCount; i++) {
      final angle = (2 * math.pi / tickCount) * i + rotation;
      final isMajor = i % 6 == 0;
      final tickLength = isMajor ? 6.0 : 3.0;

      final start = Offset(
        center.dx + (radius - tickLength) * math.cos(angle),
        center.dy + (radius - tickLength) * math.sin(angle),
      );
      final end = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      canvas.drawLine(start, end, isMajor ? (tickPaint..strokeWidth = 1.8) : (tickPaint..strokeWidth = 1.0));
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitalRingPainter oldDelegate) {
    return oldDelegate.rotation != rotation || oldDelegate.color != color;
  }
}
