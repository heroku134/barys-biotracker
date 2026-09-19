import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../domain/avatar/avatar_manager.dart';

class BioAvatarWidget extends StatefulWidget {
  final AvatarVisualState state;
  final int bpm;
  final double size;
  final VoidCallback? onTap;

  const BioAvatarWidget({
    super.key,
    required this.state,
    required this.bpm,
    this.size = 280,
    this.onTap,
  });

  @override
  State<BioAvatarWidget> createState() => _BioAvatarWidgetState();
}

class _BioAvatarWidgetState extends State<BioAvatarWidget>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _heartbeatController;
  late AnimationController _tapBounceController;

  final List<_FloatingParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // 1. Контроллер дыхания (4.5с для бодрого, 6с для уставшего)
    _breathController = AnimationController(
      vsync: this,
      duration: _getBreathDuration(),
    )..repeat();

    // 2. Контроллер пульсации био-реактора в такт пульсу
    _heartbeatController = AnimationController(
      vsync: this,
      duration: _getHeartbeatDuration(),
    )..repeat();

    // 3. Контроллер пружинного отскока при тапе
    _tapBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );

    _initParticles();
  }

  void _initParticles() {
    _particles.clear();
    final count = (widget.state == AvatarVisualState.tired || widget.state == AvatarVisualState.sleep)
        ? 5
        : 8;
    for (var i = 0; i < count; i++) {
      _ParticleType type;
      switch (widget.state) {
        case AvatarVisualState.sleep:
        case AvatarVisualState.tired:
          type = _ParticleType.zzz;
          break;
        case AvatarVisualState.meditation:
          type = _ParticleType.ripple;
          break;
        case AvatarVisualState.postWorkout:
          type = _ParticleType.droplet;
          break;
        case AvatarVisualState.charged:
          type = _ParticleType.spark;
          break;
        case AvatarVisualState.normal:
          type = _ParticleType.ambient;
          break;
      }

      _particles.add(_FloatingParticle(
        x: 0.15 + _random.nextDouble() * 0.7,
        y: 0.25 + _random.nextDouble() * 0.65,
        size: 10 + _random.nextDouble() * 14,
        speed: 0.003 + _random.nextDouble() * 0.004,
        opacity: 0.2 + _random.nextDouble() * 0.7,
        type: type,
      ));
    }
  }

  Duration _getBreathDuration() {
    switch (widget.state) {
      case AvatarVisualState.sleep:
        return const Duration(milliseconds: 6500);
      case AvatarVisualState.meditation:
        return const Duration(milliseconds: 6800);
      case AvatarVisualState.tired:
        return const Duration(milliseconds: 5500);
      case AvatarVisualState.postWorkout:
        return const Duration(milliseconds: 3200);
      case AvatarVisualState.charged:
        return const Duration(milliseconds: 3800);
      case AvatarVisualState.normal:
        return const Duration(milliseconds: 4500);
    }
  }

  Duration _getHeartbeatDuration() {
    final ms = (60000 / widget.bpm.clamp(40, 220)).round();
    return Duration(milliseconds: ms);
  }

  @override
  void didUpdateWidget(covariant BioAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _breathController.duration = _getBreathDuration();
      if (!_breathController.isAnimating) _breathController.repeat();
      _initParticles();
    }
    if (oldWidget.bpm != widget.bpm) {
      _heartbeatController.duration = _getHeartbeatDuration();
      if (!_heartbeatController.isAnimating) _heartbeatController.repeat();
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _heartbeatController.dispose();
    _tapBounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    _tapBounceController
        .animateTo(0.92, duration: const Duration(milliseconds: 100), curve: Curves.easeIn)
        .then((_) {
      _tapBounceController.animateTo(1.0,
          duration: const Duration(milliseconds: 350), curve: Curves.elasticOut);
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _breathController,
          _heartbeatController,
          _tapBounceController,
        ]),
        builder: (context, child) {
          // Кинематика дыхания: синусоидальное масштабирование
          final breathPhase = _breathController.value * 2 * math.pi;
          final breathScaleY = 1.0 + 0.032 * math.sin(breathPhase);
          final breathScaleX = 1.0 - 0.015 * math.sin(breathPhase);
          final tapScale = _tapBounceController.value;

          return SizedBox(
            width: widget.size,
            height: widget.size * 1.12,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Внешняя аура персонажа в стиле Circa
                Container(
                  width: widget.size * 0.9,
                  height: widget.size * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.state.badgeColor.withValues(alpha: 0.24),
                        blurRadius: 36,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                ),

                // 2. Тело персонажа с кинематикой дыхания и пружиной тапа
                Transform.scale(
                  scaleX: breathScaleX * tapScale,
                  scaleY: breathScaleY * tapScale,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.state.badgeColor.withValues(alpha: 0.7),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.state.badgeColor.withValues(alpha: 0.25),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        widget.state.assetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.raised,
                            child: const Center(
                              child: Icon(Icons.pets, size: 80, color: AppColors.amber),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // 3. Парящие частицы (Искры энергии или Zzz)
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _ParticlePainter(
                    particles: _particles,
                    state: widget.state,
                    progress: _breathController.value,
                  ),
                ),

                // 5. Статусный бейдж внизу
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bgDark.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.state.badgeColor,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.state.badgeColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.state.badgeColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.state.badgeText,
                          style: TextStyle(
                            color: widget.state.badgeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _ParticleType { spark, zzz, droplet, ripple, ambient }

class _FloatingParticle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;
  _ParticleType type;

  _FloatingParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.type,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_FloatingParticle> particles;
  final AvatarVisualState state;
  final double progress;

  _ParticlePainter({
    required this.particles,
    required this.state,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final currentY = (p.y - progress * 0.4) % 1.0;
      final posX = p.x * size.width;
      final posY = currentY * size.height;

      switch (p.type) {
        case _ParticleType.zzz:
          final color = state == AvatarVisualState.sleep ? AppColors.sage : AppColors.rose;
          final textPainter = TextPainter(
            text: TextSpan(
              text: 'z',
              style: TextStyle(
                color: color.withValues(alpha: p.opacity * 0.8),
                fontSize: p.size,
                fontWeight: FontWeight.w700,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(canvas, Offset(posX, posY));
          break;

        case _ParticleType.ripple:
          final ripplePaint = Paint()
            ..color = AppColors.sage.withValues(alpha: p.opacity * 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawCircle(Offset(posX, posY), p.size * (0.4 + (progress % 0.5)), ripplePaint);
          break;

        case _ParticleType.droplet:
          final dropPaint = Paint()
            ..color = AppColors.amber.withValues(alpha: p.opacity * 0.75)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(posX, posY), p.size * 0.22, dropPaint);
          break;

        case _ParticleType.spark:
          final sparkPaint = Paint()
            ..color = AppColors.amber.withValues(alpha: p.opacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
          canvas.drawCircle(Offset(posX, posY), p.size * 0.25, sparkPaint);
          break;

        case _ParticleType.ambient:
          final ambientPaint = Paint()
            ..color = AppColors.line.withValues(alpha: p.opacity * 0.6)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(posX, posY), p.size * 0.18, ambientPaint);
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
