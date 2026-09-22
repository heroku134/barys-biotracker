import 'dart:async';
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
  final BarysEvolutionTier evolutionTier;
  final String? activeSpeechBubble;
  final Function(String quote)? onQuoteSpoken;

  const BioAvatarWidget({
    super.key,
    required this.state,
    required this.bpm,
    this.size = 280,
    this.onTap,
    this.evolutionTier = BarysEvolutionTier.cadet,
    this.activeSpeechBubble,
    this.onQuoteSpoken,
  });

  @override
  State<BioAvatarWidget> createState() => _BioAvatarWidgetState();
}

class _BioAvatarWidgetState extends State<BioAvatarWidget>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _heartbeatController;
  late AnimationController _tapBounceController;
  late AnimationController _headTiltController;
  late AnimationController _speechController;

  final List<_FloatingParticle> _particles = [];
  final math.Random _random = math.Random();

  String? _displayedSpeech;
  Timer? _speechDismissTimer;
  int _tapCount = 0;

  @override
  void initState() {
    super.initState();

    // 1. Контроллер дыхания (4.5с для бодрого, 6с для уставшего)
    _breathController = AnimationController(
      vsync: this,
      duration: _getBreathDuration(),
    )..repeat();

    // 2. Контроллер пульсации в такт пульсу
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

    // 4. Контроллер покачивания головой при тапе (живая реакция)
    _headTiltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // 5. Контроллер всплывающего облачка речи
    _speechController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    if (widget.activeSpeechBubble != null) {
      _showSpeech(widget.activeSpeechBubble!);
    }

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
    if (widget.activeSpeechBubble != null &&
        widget.activeSpeechBubble != oldWidget.activeSpeechBubble) {
      _showSpeech(widget.activeSpeechBubble!);
    }
  }

  @override
  void dispose() {
    _speechDismissTimer?.cancel();
    _breathController.dispose();
    _heartbeatController.dispose();
    _tapBounceController.dispose();
    _headTiltController.dispose();
    _speechController.dispose();
    super.dispose();
  }

  void _showSpeech(String text) {
    _speechDismissTimer?.cancel();
    setState(() {
      _displayedSpeech = text;
    });
    _speechController.forward(from: 0.0);
    _speechDismissTimer = Timer(const Duration(milliseconds: 3800), () {
      if (mounted) {
        _speechController.reverse();
      }
    });
  }

  void _handleTap() {
    // 1. Двойной тактильный отклик Apple Haptic
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 140), () {
      HapticFeedback.lightImpact();
    });

    // 2. Кинематический вздох / пружинный отскок
    _tapBounceController
        .animateTo(0.91, duration: const Duration(milliseconds: 90), curve: Curves.easeIn)
        .then((_) {
      _tapBounceController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.elasticOut,
      );
    });

    // 3. Покачивание головой (tilt & bobble)
    _headTiltController.forward(from: 0.0);

    // 4. Живая реплика Барыса
    _tapCount++;
    final quote = AvatarManager.getRandomTapReaction(_tapCount);
    _showSpeech(quote);
    widget.onQuoteSpoken?.call(quote);

    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.evolutionTier;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _breathController,
          _heartbeatController,
          _tapBounceController,
          _headTiltController,
          _speechController,
        ]),
        builder: (context, child) {
          // Кинематика дыхания: синусоидальное масштабирование
          final breathPhase = _breathController.value * 2 * math.pi;
          final breathScaleY = 1.0 + 0.032 * math.sin(breathPhase);
          final breathScaleX = 1.0 - 0.015 * math.sin(breathPhase);
          final tapScale = _tapBounceController.value;

          // Кинематика покачивания головой при тапе
          final tiltProgress = _headTiltController.value;
          final headTilt = math.sin(tiltProgress * math.pi * 3) * 0.055 * (1.0 - tiltProgress);

          return SizedBox(
            width: widget.size,
            height: widget.size * 1.34,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // 1. Всплывающее облачко речи над головой Барыса
                if (_displayedSpeech != null)
                  Positioned(
                    top: 0,
                    left: 4,
                    right: 4,
                    child: Opacity(
                      opacity: _speechController.value,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1.0 - _speechController.value)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: tier.auraColor.withValues(alpha: 0.6),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: tier.auraColor.withValues(alpha: 0.18),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    color: tier.auraColor,
                                    size: 14,
                                  ),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _displayedSpeech!,
                                      style: TextStyle(
                                        color: AppColors.fg,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Маленький треугольный указатель к голове
                            CustomPaint(
                              size: const Size(12, 6),
                              painter: _SpeechBubbleArrowPainter(color: AppColors.surface),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 2. Внешняя аура персонажа в стиле Circa (с цветом ранга эволюции)
                Positioned(
                  top: widget.size * 0.22,
                  child: Container(
                    width: widget.size * 0.9,
                    height: widget.size * 0.9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: tier.auraColor.withValues(alpha: 0.22),
                          blurRadius: 36,
                          spreadRadius: 6,
                        ),
                        BoxShadow(
                          color: widget.state.badgeColor.withValues(alpha: 0.16),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Тело персонажа с кинематикой дыхания, наклона головы и пружины тапа
                Positioned(
                  top: widget.size * 0.18,
                  child: Transform.rotate(
                    angle: headTilt,
                    origin: Offset(0, widget.size * 0.4),
                    child: Transform.scale(
                      scaleX: breathScaleX * tapScale,
                      scaleY: breathScaleY * tapScale,
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: tier.auraColor.withValues(alpha: 0.75),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tier.auraColor.withValues(alpha: 0.3),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Transform.translate(
                            offset: const Offset(0, 10),
                            child: Image.asset(
                              widget.state.assetFor(),
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: AppColors.raised,
                                  child: Center(
                                    child: Icon(Icons.pets, size: 80, color: AppColors.amber),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. Парящие частицы (Искры энергии или Zzz)
                Positioned(
                  top: widget.size * 0.18,
                  child: CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _ParticlePainter(
                      particles: _particles,
                      state: widget.state,
                      progress: _breathController.value,
                    ),
                  ),
                ),

                // 5. Верхний бейдж эволюционной ступени (Кадет / Сарбаз / Батыр / Аксакал)
                Positioned(
                  top: widget.size * 0.14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.stage.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: tier.auraColor,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: tier.auraColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tier.auraColor,
                          ),
                        ),
                        SizedBox(width: 5),
                        Text(
                          tier.shortName.toUpperCase(),
                          style: TextStyle(
                            color: tier.auraColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 6. Статусный бейдж физиологического состояния внизу
                Positioned(
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bgDark.withValues(alpha: 0.88),
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
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.state.badgeColor,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          widget.state.badgeText,
                          style: TextStyle(
                            color: widget.state.badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${widget.bpm} BPM',
                          style: TextStyle(
                            color: AppColors.fg,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
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

class _SpeechBubbleArrowPainter extends CustomPainter {
  final Color color;

  _SpeechBubbleArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _ParticleType { zzz, spark, ripple, droplet, ambient }

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
      final currentY = (p.y - progress * p.speed * 80) % 1.0;
      final offset = Offset(p.x * size.width, currentY * size.height);

      final paint = Paint()
        ..color = state.badgeColor.withValues(alpha: p.opacity * 0.6)
        ..style = PaintingStyle.fill;

      switch (p.type) {
        case _ParticleType.zzz:
          final textPainter = TextPainter(
            text: TextSpan(
              text: 'z',
              style: TextStyle(
                color: state.badgeColor.withValues(alpha: p.opacity),
                fontSize: p.size,
                fontWeight: FontWeight.w700,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(canvas, offset);
          break;

        case _ParticleType.spark:
          canvas.drawCircle(offset, p.size * 0.18, paint);
          break;

        case _ParticleType.ripple:
          final ringPaint = Paint()
            ..color = state.badgeColor.withValues(alpha: p.opacity * 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          canvas.drawCircle(offset, p.size * 0.4, ringPaint);
          break;

        case _ParticleType.droplet:
        case _ParticleType.ambient:
          canvas.drawCircle(offset, p.size * 0.12, paint);
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
