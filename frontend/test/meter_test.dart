import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/sensor_service.dart';
import 'dart:math' as math;

void main() {
  final sensorService = SensorService();

  group('SensorService EV Calculation', () {
    test('calculateEV returns correct value for given aperture and shutter speed', () {
      // EV = log2(N^2 / t)
      // N=2.8, t=1/100 => EV = log2(2.8^2 / (1/100)) = log2(7.84 * 100) = log2(784)
      // log2(784) = ln(784) / ln(2) approx 9.6147
      final ev = sensorService.calculateEV(2.8, 1/100);
      expect(ev, closeTo(9.6147, 0.001));
    });

    test('estimateEVFromLux returns correct value for ISO 100', () {
      // EV100 = log2(Lux / 2.5)
      // Lux=250 => EV = log2(250 / 2.5) = log2(100) approx 6.6438
      final ev = sensorService.estimateEVFromLux(250, iso: 100);
      expect(ev, closeTo(6.6438, 0.001));
    });

    test('calculateShutterSpeed returns correct reciprocal speed', () {
      // t = N^2 / 2^EV
      // N=4, EV=10 => t = 16 / 2^10 = 16 / 1024 = 1/64
      final t = sensorService.calculateShutterSpeed(4.0, 10.0);
      expect(t, closeTo(1/64, 0.0001));
    });
  });
}
