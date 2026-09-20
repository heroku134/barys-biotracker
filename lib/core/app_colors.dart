import 'package:flutter/material.dart';

/// Precision Biometric Palette (Whoop 5.0 / Oura Athletic / Swiss Precision)
/// - Background: Dark obsidian (#08090C, in #050506–#12141A range)
/// - Surface: Flat card surface (#0E1015) with 1px hairline border (#1C2029)
/// - Text: Near-white (#EDEDED), Secondary grey (#8A909D), Muted grey (#454B59)
/// - Exactly 3 accents:
///   1. sage (#52B788) — Recovery / optimal / good
///   2. amber (#DE8A36) — Strain / load / target
///   3. rose (#D14949) — Heart rate / alert
class AppColors {
  // 1. Dark obsidian background & flat surfaces
  static const Color obsidian = Color(0xFF08090C); // #08090C (in #050506–#12141A range)
  static const Color stage = obsidian;
  static const Color bg = obsidian;
  static const Color surface = Color(0xFF0E1015);  // Flat card surface (no blur, no glass)
  static const Color raised = Color(0xFF161922);   // Inner tracks, progress backgrounds

  // 2. 1px hairline borders
  static const Color hairline = Color(0xFF1C2029); // 1px border for flat cards
  static const Color line = hairline;
  static const Color lineStrong = Color(0xFF282E3B);

  // 3. Typography hierarchy (Near-white + 2 greys)
  static const Color textNearWhite = Color(0xFFEDEDED); // Near-white text
  static const Color fg = textNearWhite;
  static const Color textSecondary = Color(0xFF8A909D); // Grey 1: secondary labels & units
  static const Color secondary = textSecondary;
  static const Color muted = textSecondary;
  static const Color textMuted = Color(0xFF454B59);     // Grey 2: disabled/tertiary/track
  static const Color faint = textMuted;

  // 4. EXACTLY THREE ACCENTS (No cyan, no purple, no rainbow gradients)
  static const Color sage = Color(0xFF52B788);  // Muted sage green (recovery / good)
  static const Color amber = Color(0xFFDE8A36); // Warm amber (strain / load)
  static const Color rose = Color(0xFFD14949);  // Muted rose-red (heart rate / alert)

  // Backward-compatibility aliases
  static const Color cyan = sage;
  static const Color accent = fg;
  static const Color bgDark = obsidian;
  static const Color surfaceCard = surface;
  static const Color borderGlass = hairline;
  static const Color textPrimary = fg;
  static const Color emerald = sage;
  static const Color gold = amber;
  static const Color pulseRed = rose;

  // Discrete zones mapped to the 3 accents
  static const Color zoneOptimal = sage;
  static const Color zoneModerate = amber;
  static const Color zoneLow = rose;
}
