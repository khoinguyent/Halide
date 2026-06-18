import 'package:flutter/material.dart';

/// Maps calibrated Kelvin white-balance targets to on-screen backlight colors.
Color getColorFromTemperature(double kelvin) {
  if (kelvin < 5500) {
    // Warm/Amber shift to compensate for cold scans
    return const Color(0xFFFFF7EF);
  } else if (kelvin > 6500) {
    // Cool/Ice-blue shift to compensate for warm film bases
    return const Color(0xFFF2F8FF);
  }
  return const Color(0xFFFFFFFF); // D65 Balanced Daylight White
}

/// Design tokens for the Light Table zinc control chrome.
abstract final class LightTableTokens {
  /// Matches the glass dock outlined icon style (see [GlassNavigationDock]).
  static const IconData navIcon = Icons.wb_sunny_outlined;

  static const Color zinc900 = Color(0xFF18181B);
  static const Color zinc300 = Color(0xFFD4D4D8);
  static const double kelvinMin = 5000;
  static const double kelvinMax = 7000;
  static const double kelvinDefault = 6000;
  static const Duration controlsIdleTimeout = Duration(seconds: 5);
  static const Duration unlockHoldDuration = Duration(milliseconds: 3000);
}
