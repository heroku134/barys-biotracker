import 'package:flutter/material.dart';

@immutable
class KalkanColors extends ThemeExtension<KalkanColors> {
  final Color bg;
  final Color surface;
  final Color raised;
  final Color hairline;
  final Color lineStrong;
  final Color fg;
  final Color secondary;
  final Color muted;
  final Color shadow;

  const KalkanColors({
    required this.bg,
    required this.surface,
    required this.raised,
    required this.hairline,
    required this.lineStrong,
    required this.fg,
    required this.secondary,
    required this.muted,
    required this.shadow,
  });

  static const dark = KalkanColors(
    bg: Color(0xFF08090C),
    surface: Color(0xFF0E1015),
    raised: Color(0xFF161922),
    hairline: Color(0xFF1C2029),
    lineStrong: Color(0xFF282E3B),
    fg: Color(0xFFEDEDED),
    secondary: Color(0xFF8A909D),
    muted: Color(0xFF454B59),
    shadow: Color(0x00000000),
  );

  static const light = KalkanColors(
    bg: Color(0xFFF6F6F4),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFEEEEEC),
    hairline: Color(0xFFE2E2DE),
    lineStrong: Color(0xFFD0D0CA),
    fg: Color(0xFF121212),
    secondary: Color(0xFF5A5A5A),
    muted: Color(0xFF8A8A8A),
    shadow: Color(0x14000000),
  );

  static KalkanColors of(BuildContext context) {
    return Theme.of(context).extension<KalkanColors>() ?? AppColors._t;
  }

  @override
  KalkanColors copyWith({
    Color? bg,
    Color? surface,
    Color? raised,
    Color? hairline,
    Color? lineStrong,
    Color? fg,
    Color? secondary,
    Color? muted,
    Color? shadow,
  }) {
    return KalkanColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      raised: raised ?? this.raised,
      hairline: hairline ?? this.hairline,
      lineStrong: lineStrong ?? this.lineStrong,
      fg: fg ?? this.fg,
      secondary: secondary ?? this.secondary,
      muted: muted ?? this.muted,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  KalkanColors lerp(ThemeExtension<KalkanColors>? other, double t) {
    if (other is! KalkanColors) return this;
    return KalkanColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      fg: Color.lerp(fg, other.fg, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

class DynamicColor extends Color {
  final Color Function() _resolver;

  const DynamicColor(this._resolver, [int defaultValue = 0xFF0E1015]) : super(defaultValue);

  @override
  int get value => _resolver().toARGB32();

  @override
  int toARGB32() => _resolver().toARGB32();

  @override
  int get alpha => _resolver().alpha;

  @override
  double get a => _resolver().a;

  @override
  double get r => _resolver().r;

  @override
  double get g => _resolver().g;

  @override
  double get b => _resolver().b;

  @override
  Color withValues({double? alpha, double? red, double? green, double? blue, dynamic colorSpace}) {
    return _resolver().withValues(alpha: alpha, red: red, green: green, blue: blue, colorSpace: colorSpace);
  }

  @override
  Color withAlpha(int a) => _resolver().withAlpha(a);

  @override
  Color withOpacity(double opacity) => _resolver().withOpacity(opacity);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is Color) {
      return toARGB32() == other.toARGB32();
    }
    return false;
  }

  @override
  int get hashCode => _resolver().toARGB32().hashCode;
}

Color _getBg() => AppColors._t.bg;
Color _getSurface() => AppColors._t.surface;
Color _getRaised() => AppColors._t.raised;
Color _getHairline() => AppColors._t.hairline;
Color _getLineStrong() => AppColors._t.lineStrong;
Color _getFg() => AppColors._t.fg;
Color _getSecondary() => AppColors._t.secondary;
Color _getMuted() => AppColors._t.muted;
Color _getShadow() => AppColors._t.shadow;

/// Accents stay constant. Surfaces follow the active theme.
class AppColors {
  static bool light = false;
  static KalkanColors get _t => light ? KalkanColors.light : KalkanColors.dark;

  static const Color sage = Color(0xFF3D9B74);
  static const Color amber = Color(0xFFC57A2A);
  static const Color rose = Color(0xFFC45C5C);
  static const Color sleepBlue = Color(0xFF6E86A8);
  static const Color strainBlue = Color(0xFF3D73C4);

  static const Color obsidian = DynamicColor(_getBg, 0xFF08090C);
  static const Color stage = DynamicColor(_getBg, 0xFF08090C);
  static const Color bg = DynamicColor(_getBg, 0xFF08090C);
  static const Color bgDark = DynamicColor(_getBg, 0xFF08090C);

  static const Color surface = DynamicColor(_getSurface, 0xFF0E1015);
  static const Color surfaceCard = DynamicColor(_getSurface, 0xFF0E1015);

  static const Color raised = DynamicColor(_getRaised, 0xFF161922);

  static const Color hairline = DynamicColor(_getHairline, 0xFF1C2029);
  static const Color line = DynamicColor(_getHairline, 0xFF1C2029);
  static const Color borderGlass = DynamicColor(_getHairline, 0xFF1C2029);

  static const Color lineStrong = DynamicColor(_getLineStrong, 0xFF282E3B);

  static const Color textNearWhite = DynamicColor(_getFg, 0xFFEDEDED);
  static const Color fg = DynamicColor(_getFg, 0xFFEDEDED);
  static const Color textPrimary = DynamicColor(_getFg, 0xFFEDEDED);
  static const Color accent = DynamicColor(_getFg, 0xFFEDEDED);

  static const Color textSecondary = DynamicColor(_getSecondary, 0xFF8A909D);
  static const Color secondary = DynamicColor(_getSecondary, 0xFF8A909D);

  static const Color muted = DynamicColor(_getMuted, 0xFF454B59);
  static const Color textMuted = DynamicColor(_getMuted, 0xFF454B59);
  static const Color faint = DynamicColor(_getMuted, 0xFF454B59);
  static const Color shadow = DynamicColor(_getShadow, 0x00000000);

  static const Color cyan = sage;
  static const Color emerald = sage;
  static const Color gold = amber;
  static const Color pulseRed = rose;
  static const Color zoneOptimal = sage;
  static const Color zoneModerate = amber;
  static const Color zoneLow = rose;

  static KalkanColors of(BuildContext context) => KalkanColors.of(context);
}
