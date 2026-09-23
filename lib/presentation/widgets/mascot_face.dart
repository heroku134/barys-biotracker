import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../data/storage/climate_mode_store.dart';
import '../../domain/avatar/avatar_manager.dart';

class MascotFace extends StatefulWidget {
  final AvatarVisualState state;
  final double size;
  final ClimateMode climate;
  final VoidCallback? onTap;

  const MascotFace({
    super.key,
    required this.state,
    this.size = 56,
    this.climate = ClimateMode.normal,
    this.onTap,
  });

  @override
  State<MascotFace> createState() => _MascotFaceState();
}

class _MascotFaceState extends State<MascotFace> with TickerProviderStateMixin {
  late AnimationController _breath;
  late AnimationController _blink;

  bool get _sleep => widget.state == AvatarVisualState.sleep;
  bool get _canBlink =>
      widget.state == AvatarVisualState.normal || widget.state == AvatarVisualState.charged;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(vsync: this, duration: Duration(milliseconds: _sleep ? 4200 : 2800));
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 140));
    _breath.repeat(reverse: true);
    _loopBlink();
  }

  Future<void> _loopBlink() async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 6000 + DateTime.now().millisecond % 2000));
      if (!mounted || !_canBlink) continue;
      await _blink.forward();
      await _blink.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant MascotFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _breath.duration = Duration(milliseconds: _sleep ? 4200 : 2800);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _blink.dispose();
    super.dispose();
  }

  Color get _wash {
    switch (widget.climate) {
      case ClimateMode.altitude:
        return const Color(0x402A4A6A);
      case ClimateMode.heat:
        return const Color(0x40C47A3A);
      case ClimateMode.normal:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breath, _blink]),
        builder: (context, _) {
          final scale = _sleep ? 1.0 + _breath.value * 0.008 : 1.0 + _breath.value * 0.02;
          final blink = _canBlink ? _blink.value : 0.0;
          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      widget.state.assetFor(),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: AppColors.raised,
                        child: Icon(Icons.pets, color: AppColors.amber, size: widget.size * 0.4),
                      ),
                    ),
                    if (_wash.a > 0) ColoredBox(color: _wash),
                    if (blink > 0)
                      Align(
                        alignment: Alignment.topCenter,
                        child: FractionallySizedBox(
                          heightFactor: 0.22 * blink,
                          child: const ColoredBox(color: Colors.black87),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
