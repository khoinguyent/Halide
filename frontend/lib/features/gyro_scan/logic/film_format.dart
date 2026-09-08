import 'package:flutter/material.dart';

/// Film format options available in the gyro scanner.
///
/// Each variant carries its own frame aspect ratio and box-sizing logic so
/// the HUD overlay can draw the correct guide rectangle and the crop pipeline
/// can centre-crop the capture to exactly the right proportions.
enum FilmFormat {
  /// 35 mm — 36 × 24 mm frame, 3∶2 landscape.
  mm35,

  /// 120 medium format — 60 × 45 mm frame, 4∶3 landscape.
  mm120_645,

  /// 120 medium format — 60 × 60 mm frame, 1∶1 square.
  mm120_66,

  /// 120 medium format — 60 × 70 mm frame, 6∶7 portrait.
  mm120_67;

  // ── Properties ─────────────────────────────────────────────────────────────

  /// Frame width ÷ frame height.  Values < 1.0 are portrait frames.
  double get frameAspect => switch (this) {
        mm35      => 3 / 2,   // 36 × 24 mm
        mm120_645 => 4 / 3,   // 60 × 45 mm
        mm120_66  => 1.0,     // 60 × 60 mm
        mm120_67  => 6 / 7,   // 60 × 70 mm
      };

  String get displayName => switch (this) {
        mm35      => '35 mm',
        mm120_645 => '120 · 6×4.5',
        mm120_66  => '120 · 6×6',
        mm120_67  => '120 · 6×7',
      };

  String get shortName => switch (this) {
        mm35      => '35mm',
        mm120_645 => '6×4.5',
        mm120_66  => '6×6',
        mm120_67  => '6×7',
      };

  bool get isMediumFormat => this != mm35;

  /// 120 sub-formats available when the roll's film stock is 120 / medium.
  static const mediumFormatOptions = [
    FilmFormat.mm120_645,
    FilmFormat.mm120_66,
    FilmFormat.mm120_67,
  ];

  /// Maps a film-stock [format] key (`format_135`, `format_120`, …) to the
  /// default gyro-scan frame guide.
  ///
  /// For 120 rolls the default is 6×6; use [mediumFormatOptions] to let the
  /// user pick 6×4.5 or 6×7.
  static FilmFormat fromFilmStockFormat(String? format) {
    switch (format) {
      case 'format_120':
      case 'format_large':
        return FilmFormat.mm120_66;
      case 'format_135':
      default:
        return FilmFormat.mm35;
    }
  }

  /// True when the roll's film stock is 120 / medium / large format.
  static bool isMediumFilmStock(String? format) =>
      format == 'format_120' || format == 'format_large';

  /// Picker options allowed for this roll's film stock.
  static List<FilmFormat> optionsForFilmStock(String? format) =>
      isMediumFilmStock(format) ? mediumFormatOptions : [FilmFormat.mm35];

  // ── Frame-box geometry ─────────────────────────────────────────────────────

  /// Returns the [Rect] of the frame-guide box, centred within [screen] and
  /// scaled so it fits between the HUD top-bar and bottom controls.
  Rect frameBox(Size screen) {
    // Vertical guards: leave room for top bar + bottom carousel/controls.
    const topGuard = 74.0;
    const botGuard = 184.0;
    final availH = screen.height - topGuard - botGuard;
    final centerY = topGuard + availH / 2;
    final centerX = screen.width / 2;

    final maxW = screen.width * 0.82;
    final maxH = availH * 0.90;

    final ar = frameAspect;
    double w, h;
    if (ar >= 1.0) {
      // Landscape or square — constrain by width first.
      w = maxW;
      h = w / ar;
      if (h > maxH) {
        h = maxH;
        w = h * ar;
      }
    } else {
      // Portrait — constrain by height first.
      h = maxH;
      w = h * ar;
      if (w > maxW) {
        w = maxW;
        h = w / ar;
      }
    }

    return Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: w,
      height: h,
    );
  }

  /// Normalized frame-guide bounds relative to the full-screen HUD (0.0–1.0).
  ///
  /// Passed into the capture pipeline so the saved JPEG is cropped to exactly
  /// the on-screen guide rectangle before C-41 inversion.
  ({double top, double left, double width, double height}) normalizedFrameGuideRect(
    Size screen,
  ) {
    final box = frameBox(screen);
    return (
      top: box.top / screen.height,
      left: box.left / screen.width,
      width: box.width / screen.width,
      height: box.height / screen.height,
    );
  }
}
