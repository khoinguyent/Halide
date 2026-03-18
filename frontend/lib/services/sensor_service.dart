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

  /// Calculates Exposure Value (EV) from aperture (N) and shutter speed (t).
  /// Formula: EV = log2(N^2 / t)
  double calculateEV(double aperture, double shutterSpeed) {
    if (aperture <= 0 || shutterSpeed <= 0) return 0.0;
    return math.log(math.pow(aperture, 2) / shutterSpeed) / math.ln2;
  }

  /// Estimates EV from Lux using the incident light constant (C).
  /// Common value for C is 250 (for reflected light it's usually 12.5-14).
  /// Formula: EV = log2(Lux * S / C) where S is ISO.
  /// Standard EV (at ISO 100): EV100 = log2(Lux / 2.5)
  double estimateEVFromLux(double lux, {double iso = 100}) {
    if (lux <= 0) return 0.0;
    // EV = log2(Lux * ISO / 250) is a common estimation for incident light
    // At ISO 100: EV = log2(Lux / 2.5)
    return math.log(lux * iso / 250.0) / math.ln2;
  }

  /// Calculates reciprocal exposure: returns shutter speed (t) 
  /// for a given aperture (N) and EV.
  /// Formula: t = N^2 / 2^EV
  double calculateShutterSpeed(double aperture, double ev) {
    if (aperture <= 0) return 0.0;
    return math.pow(aperture, 2) / math.pow(2, ev);
  }
}
