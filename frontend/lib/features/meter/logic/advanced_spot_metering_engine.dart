import 'dart:math' as math;
import 'dart:ui';

/// Mathematical core for Advanced Spot Metering (Zone System + Multi-Spot).
///
/// Reflected-light calibration constant K = 12.5 (ISO 100 basis).
class AdvancedSpotMeteringEngine {
  AdvancedSpotMeteringEngine._();

  static const double calibrationK = 12.5;
  static const double baseIso = 100.0;
  static const int maxPins = 5;
  static const int pinSampleRadius = 7; // 15×15 square
  static const int zoneGridWidth = 48;
  static const int zoneGridHeight = 64;

  // ── Zone false-color palette (Ansel Adams Zone System) ─────────────────

  static const List<Color> zoneColors = [
    Color(0xFF1E003B), // Zone 0 — Pure Black
    Color(0xFF001B48), // Zone I
    Color(0xFF004586), // Zone II
    Color(0xFF0080FF), // Zone III
    Color(0xFF00A3A3), // Zone IV
    Color(0xFF00FF00), // Zone V — Middle Gray
    Color(0xFF80FF00), // Zone VI
    Color(0xFFFFFF00), // Zone VII
    Color(0xFFFF8000), // Zone VIII
    Color(0xFFFF4000), // Zone IX
    Color(0xFFFF0000), // Zone X — Pure White
  ];

  // ── EV from luminance ──────────────────────────────────────────────────

  /// EV₁₀₀ from scene luminance L (cd/m²).
  /// EV₁₀₀ = log₂(L · S / K)  where S = 100.
  static double ev100FromLuminance(double luminanceCdM2) {
    if (luminanceCdM2 <= 0 || !luminanceCdM2.isFinite) return 0;
    return _log2(luminanceCdM2 * baseIso / calibrationK);
  }

  /// Adjust EV₁₀₀ for arbitrary ISO: EV_S = EV₁₀₀ + log₂(S / 100).
  static double evAtIso(double ev100, double iso) {
    if (iso <= 0) return ev100;
    return ev100 + _log2(iso / baseIso);
  }

  /// Luminance (cd/m²) from EV₁₀₀.
  static double luminanceFromEv100(double ev100) {
    return calibrationK * math.pow(2, ev100) / baseIso;
  }

  /// Pixel EV anchored to a hardware-metered reference point.
  ///
  /// Uses log-domain offset: EV_pixel = EV_anchor + log₂(Y_pixel / Y_anchor).
  static double evFromRelativeLuminance({
    required double relativeLuminance,
    required double evAnchor,
    required double anchorLuminance,
  }) {
    final y = relativeLuminance.clamp(1e-6, 1.0);
    final yRef = anchorLuminance.clamp(1e-6, 1.0);
    return evAnchor + _log2(y / yRef);
  }

  // ── Zone classification ────────────────────────────────────────────────

  /// Maps ΔEV = EV_pixel − EV_target to zone index 0–10.
  static int deltaEvToZone(double deltaEv) {
    if (deltaEv <= -5.0) return 0;
    if (deltaEv <= -4.0) return 1;
    if (deltaEv <= -3.0) return 2;
    if (deltaEv <= -2.0) return 3;
    if (deltaEv <= -1.0) return 4;
    if (deltaEv < 1.0) return 5;
    if (deltaEv < 2.0) return 6;
    if (deltaEv < 3.0) return 7;
    if (deltaEv < 4.0) return 8;
    if (deltaEv < 5.0) return 9;
    return 10;
  }

  static Color zoneColorForDeltaEv(double deltaEv) =>
      zoneColors[deltaEvToZone(deltaEv)];

  static Color zoneColorForPixelEv({
    required double pixelEv,
    required double evTarget,
  }) => zoneColorForDeltaEv(pixelEv - evTarget);

  // ── Multi-spot average ─────────────────────────────────────────────────

  static double averageEv(Iterable<double> pinEvs) {
    final list = pinEvs.where((e) => e.isFinite).toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  // ── Reciprocal exposure: N²/t = S · 2^EV / K ──────────────────────────

  /// Shutter speed (seconds) for aperture N at EV and ISO.
  static double shutterFromReciprocity({
    required double aperture,
    required double ev,
    required double iso,
  }) {
    if (aperture <= 0) return 0;
    final numerator = math.pow(aperture, 2) * calibrationK;
    final denominator = iso * math.pow(2, ev);
    return numerator / denominator;
  }

  /// Aperture (f-number) for shutter t at EV and ISO.
  static double apertureFromReciprocity({
    required double shutterSeconds,
    required double ev,
    required double iso,
  }) {
    if (shutterSeconds <= 0) return 2.8;
    final n2 = iso * math.pow(2, ev) * shutterSeconds / calibrationK;
    return math.sqrt(n2);
  }

  static double _log2(double x) => math.log(x) / math.ln2;
}
