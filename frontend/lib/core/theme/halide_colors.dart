import 'package:flutter/material.dart';
import 'halide_palette.dart';

/// Semantic color tokens for the active Halide theme, exposed via [ThemeExtension].
@immutable
class HalideColors extends ThemeExtension<HalideColors> {
  const HalideColors({
    required this.darkest,
    required this.accent,
    required this.mid,
    required this.light,
    required this.muted,
    required this.surface,
    required this.surfaceSheet,
    required this.error,
  });

  final Color darkest;
  final Color accent;
  final Color mid;
  final Color light;
  final Color muted;
  final Color surface;
  final Color surfaceSheet;
  final Color error;

  // ── Semantic roles ────────────────────────────────────────────────────────
  Color get background => darkest;
  Color get textPrimary => light;
  Color get textSecondary => muted;
  Color get textOnLight => darkest;
  Color get accentMuted => mid;
  Color get border => mid;
  Color get borderSubtle => muted.withValues(alpha: 0.4);

  // Legacy palette slot names (kept for gradual migration).
  Color get navy => darkest;
  Color get slateTeal => accent;
  Color get sage => mid;
  Color get ash => light;
  Color get steel => muted;

  Color glassFill([double opacity = 0.14]) => mid.withValues(alpha: opacity);

  Color glassBorder([double opacity = 0.28]) => mid.withValues(alpha: opacity);

  Color textMuted([double opacity = 0.72]) => light.withValues(alpha: opacity);

  Color iconMuted([double opacity = 0.55]) => muted.withValues(alpha: opacity);

  factory HalideColors.fromPalette(HalidePalette palette) {
    final d = palette.darkest;
    final a = palette.accent;
    return HalideColors(
      darkest: d,
      accent: a,
      mid: palette.mid,
      light: palette.light,
      muted: palette.muted,
      surface: Color.lerp(d, a, 0.25)!,
      surfaceSheet: Color.lerp(d, a, 0.35)!,
      error: const Color(0xFFE57373),
    );
  }

  static HalideColors of(BuildContext context) {
    return Theme.of(context).extension<HalideColors>() ?? fallback;
  }

  static final HalideColors fallback = HalidePalettes.deepHarbor.toColors();

  @override
  HalideColors copyWith({
    Color? darkest,
    Color? accent,
    Color? mid,
    Color? light,
    Color? muted,
    Color? surface,
    Color? surfaceSheet,
    Color? error,
  }) {
    return HalideColors(
      darkest: darkest ?? this.darkest,
      accent: accent ?? this.accent,
      mid: mid ?? this.mid,
      light: light ?? this.light,
      muted: muted ?? this.muted,
      surface: surface ?? this.surface,
      surfaceSheet: surfaceSheet ?? this.surfaceSheet,
      error: error ?? this.error,
    );
  }

  @override
  HalideColors lerp(ThemeExtension<HalideColors>? other, double t) {
    if (other is! HalideColors) return this;
    return HalideColors(
      darkest: Color.lerp(darkest, other.darkest, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      mid: Color.lerp(mid, other.mid, t)!,
      light: Color.lerp(light, other.light, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSheet: Color.lerp(surfaceSheet, other.surfaceSheet, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension HalidePaletteColors on HalidePalette {
  HalideColors toColors() => HalideColors.fromPalette(this);
}
