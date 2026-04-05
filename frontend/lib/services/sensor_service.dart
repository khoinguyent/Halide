import 'dart:math' as math;

// ─────────────────────────────────────────────────────────────────────────────
// Reflected-light metering engine  (light_metering.md spec)
//
// Phase A:  EV₁₀₀ = log₂(N²/t) − log₂(ISO/100)
// Phase B: optional EV calibration (was −2.0 for legacy Fuji XT-20 lab tests).
//
// Field testing vs Sekonic / other camera apps: a −2.0 EV shift made reciprocal
// shutter ~2 stops **longer** than reference (e.g. 1/8 vs 1/30 at f/2.8 ISO 100).
// Metadata EV already tracks scene brightness; use 0.0 so suggested shutter matches
// external meters. Adjust here if you re-run a controlled Fuji reference test.
// ─────────────────────────────────────────────────────────────────────────────

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  // ── Calibration ─────────────────────────────────────────────────────────

  /// EV offset applied after Phase A (raw EV₁₀₀ from N, t, ISO).
  /// Set to 0 so suggested film shutter matches phone camera meters / Sekonic in the field.
  static const double calibrationOffset = 0.0;

  // ── Standard photographic stop tables ──────────────────────────────────

  /// Standard shutter speeds in seconds (ascending). Snap only at display time.
  static const List<double> standardShutterSpeeds = [
    1 / 4000, 1 / 2000, 1 / 1000, 1 / 500, 1 / 250, 1 / 125,
    1 / 60,   1 / 30,   1 / 15,   1 / 8,   1 / 4,   1 / 2,
    1,        2,        4,        8,        15,       30,
  ];

  /// Standard aperture f-stops (ascending f-number = less light).
  static const List<double> standardApertures = [
    1.0, 1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0,
  ];

  // ── Core EV calculations ────────────────────────────────────────────────

  /// Raw EV at camera settings — NOT calibrated.
  /// Formula: EV = log₂(N² / t)
  double calculateEV(double aperture, double shutterSpeed) {
    if (aperture <= 0 || shutterSpeed <= 0) return 0.0;
    return _log2(math.pow(aperture, 2) / shutterSpeed);
  }

  /// Calibrated EV₁₀₀ from live hardware auto-exposure metadata.
  ///
  /// Phase A (spec §2): EV_raw = log₂(N² / t) − log₂(ISO / 100)
  /// Phase B: EV_final = EV_raw + calibrationOffset
  double calculateEV100(double aperture, double shutter, double iso) {
    if (aperture <= 0 || shutter <= 0 || iso <= 0) return 0.0;
    final evRaw = _log2(math.pow(aperture, 2) / shutter) - _log2(iso / 100.0);
    return evRaw + calibrationOffset;
  }

  /// Convert EXIF BrightnessValue (Bv) to EV₁₀₀.
  ///
  /// APEX system at ISO 100: EV = Bv + Sv(100) = Bv + log₂(100/3.125) = Bv + 5
  ///
  /// Use as primary path when iOS returns kCGImagePropertyExifBrightnessValue.
  /// Fall back to [calculateEV100] when Bv is unavailable.
  double evFromBrightnessValue(double bv) {
    // Sv at ISO 100 = log2(100 / 3.125) ≈ 5
    const svAt100 = 5.0;
    return bv + svAt100;
  }

  // ── Lux (display-only) ──────────────────────────────────────────────────

  /// Display-only illuminance approximation from calibrated EV₁₀₀.
  /// Formula: Lux = 2.5 × 2^EV₁₀₀   (light_metering.md §6)
  double calculateLuxFromEV100(double ev100) {
    return 2.5 * math.pow(2, ev100);
  }

  /// Estimates EV from Lux reading (incident constant C = 250).
  /// Formula: EV = log₂(Lux × ISO / 250)
  ///
  /// ⚠️  iPhone ambient Lux sensor measures INCIDENT light (ceiling/room),
  /// not REFLECTED light from the subject.  Do NOT use for primary metering.
  /// Kept only for Android fallback where an ambient sensor is the last resort.
  double estimateEVFromLux(double lux, {double iso = 100}) {
    final effectiveLux = lux <= 0 ? 0.1 : lux;
    return _log2(effectiveLux * iso / 250.0);
  }

  // ── Reciprocal exposure ─────────────────────────────────────────────────

  /// Film shutter speed for a given film aperture at a given EV.
  ///
  /// Spec §4:
  ///   EV_f = EV_final + log₂(ISO_film / 100)   [handled by caller]
  ///   t_sug = N_film² / 2^EV_f
  double calculateShutterSpeed(double aperture, double ev) {
    if (aperture <= 0) return 0.0;
    return math.pow(aperture, 2) / math.pow(2, ev);
  }

  // ── Snap logic (display step only — keep EV continuous until here) ──────

  /// Snaps a raw shutter speed to the nearest standard photographic stop.
  /// Uses log₂ space so every stop is equally weighted.
  static double snapShutterSpeed(double value) {
    if (!value.isFinite || value <= 0) return 1 / 125;
    final logVal = _log2(value);
    double best = standardShutterSpeeds.first;
    double bestDist = (logVal - _log2(best)).abs();
    for (final s in standardShutterSpeeds.skip(1)) {
      final d = (logVal - _log2(s)).abs();
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }

  /// Snaps a raw aperture to the nearest standard photographic stop.
  static double snapAperture(double value) {
    if (!value.isFinite || value <= 0) return 2.8;
    final logVal = _log2(value);
    double best = standardApertures.first;
    double bestDist = (logVal - _log2(best)).abs();
    for (final s in standardApertures.skip(1)) {
      final d = (logVal - _log2(s)).abs();
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }

  static double _log2(double x) => math.log(x) / math.ln2;
}
