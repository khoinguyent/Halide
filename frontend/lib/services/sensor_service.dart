import 'dart:async';
import 'dart:math' as math;
import 'package:light_sensor/light_sensor.dart';

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  Stream<double>? _luxStream;

  /// Returns a stream of Lux (illuminance) values.
  Stream<double> get luxStream {
    _luxStream ??= LightSensor.luxStream().asBroadcastStream().map((lux) => lux.toDouble());
    return _luxStream!;
  }

  /// Calibration offset applied to EV100 derived from hardware metadata.
  /// Modern iPhone sensors overexpose to preserve shadow detail; a negative
  /// offset brings readings in line with professional reflected-light meters.
  static const double calibrationOffset = -0.7;

  /// Standard photographic shutter speeds in seconds (ascending).
  static const List<double> standardShutterSpeeds = [
    1 / 4000, 1 / 2000, 1 / 1000, 1 / 500, 1 / 250, 1 / 125,
    1 / 60, 1 / 30, 1 / 15, 1 / 8, 1 / 4, 1 / 2,
    1, 2, 4, 8, 15, 30,
  ];

  /// Standard photographic aperture stops.
  static const List<double> standardApertures = [
    1.0, 1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0,
  ];

  /// Calculates Exposure Value (EV) from aperture (N) and shutter speed (t).
  /// Formula: EV = log2(N² / t)
  double calculateEV(double aperture, double shutterSpeed) {
    if (aperture <= 0 || shutterSpeed <= 0) return 0.0;
    return _log2(math.pow(aperture, 2) / shutterSpeed);
  }

  /// Calculates EV100 from hardware auto-exposure settings with calibration.
  /// Formula: EV100 = log2(N² / t) - log2(ISO / 100) + calibrationOffset
  double calculateEV100(double aperture, double shutter, double iso) {
    if (aperture <= 0 || shutter <= 0 || iso <= 0) return 0.0;
    final evAtSettings = _log2(math.pow(aperture, 2) / shutter);
    final ev100 = evAtSettings - _log2(iso / 100.0);
    return ev100 + calibrationOffset;
  }

  /// Display-only Lux approximation derived from EV100.
  /// Formula: Lux = 2.5 × 2^EV100
  double calculateLuxFromEV100(double ev100) {
    return 2.5 * math.pow(2, ev100);
  }

  /// Estimates EV from Lux using the incident light constant C = 250.
  /// Formula: EV = log2(Lux × ISO / C)
  double estimateEVFromLux(double lux, {double iso = 100}) {
    final effectiveLux = lux <= 0 ? 0.1 : lux;
    return _log2(effectiveLux * iso / 250.0);
  }

  /// Fallback: estimates EV from normalized luminance (0–1).
  /// Use [calculateEV100] with hardware metadata for professional results.
  double estimateEVFromLuminance(double luminance) {
    final effectiveLuminance = luminance <= 0 ? 0.001 : luminance;
    final luxEquivalent = effectiveLuminance * 40000.0;
    return estimateEVFromLux(luxEquivalent, iso: 100);
  }

  /// Reciprocal exposure: shutter speed for a given aperture and EV.
  /// Formula: t = N² / 2^EV
  double calculateShutterSpeed(double aperture, double ev) {
    if (aperture <= 0) return 0.0;
    return math.pow(aperture, 2) / math.pow(2, ev);
  }

  /// Snaps a raw shutter speed to the nearest standard photographic stop.
  /// Comparison is done in log₂ space so that each full stop has equal weight.
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
