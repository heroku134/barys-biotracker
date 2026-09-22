import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';

class MetricDial extends StatefulWidget {
  final String label;
  final String value;
  final double progress;
  final Color color;
  final VoidCallback? onTap;
  final double size;

  const MetricDial({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
    this.onTap,
    this.size = 104,
  });

  @override
  State<MetricDial> createState() => _MetricDialState();
}

class _MetricDialState extends State<MetricDial> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _sweep;
  late Animation<double> _pop;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _sweep = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _pop = Tween<double>(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant MetricDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.progress - widget.progress).abs() > 0.03) {
      _c.forward(from: 0.35);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = KalkanColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Transform.scale(
                scale: _pop.value,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CustomPaint(
                    painter: _DialPainter(
                      progress: (widget.progress.clamp(0.0, 1.0)) * _sweep.value,
                      color: widget.color,
                      track: palette.hairline,
                      well: dark ? const Color(0xFF10131A) : const Color(0xFFEFEFEA),
                      inner: palette.surface,
                      glow: dark,
                    ),
                    child: Center(
                      child: Text(
                        widget.value,
                        style: AppTypography.heroNumberMedium(palette.fg).copyWith(
                          fontSize: widget.size > 96 ? 26 : 20,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            widget.label,
            style: AppTypography.caption(palette.secondary).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  final Color well;
  final Color inner;
  final bool glow;

  _DialPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.well,
    required this.inner,
    this.glow = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 7;
    const start = -math.pi / 2;

    canvas.drawCircle(c, r - 1, Paint()..color = well);
    if (glow) {
      canvas.drawCircle(
        c.translate(0, 1.2),
        r - 10,
        Paint()
          ..color = const Color(0x14000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawCircle(c, r - 11, Paint()..color = inner);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, trackPaint);

    if (progress <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    final sweep = 2 * math.pi * progress;

    if (glow) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawArc(rect, start, sweep, false, glowPaint);
    }

    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    if (glow) {
      ring.shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: [
          Color.lerp(color, Colors.white, 0.35)!,
          color,
          Color.lerp(color, Colors.black, 0.25)!,
          Color.lerp(color, Colors.white, 0.35)!,
        ],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    }
    canvas.drawArc(rect, start, sweep, false, ring);

    if (glow) {
      final end = start + sweep;
      final tip = Offset(c.dx + r * math.cos(end), c.dy + r * math.sin(end));
      canvas.drawCircle(tip, 3.2, Paint()..color = Colors.white.withValues(alpha: 0.85));
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}
