import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/sensor_service.dart';
import 'dart:math' as math;

void main() {
  final sensorService = SensorService();

  group('SensorService EV Calculation', () {
    test('calculateEV returns correct value for given aperture and shutter speed', () {
      // EV = log2(N^2 / t)
      // N=2.8, t=1/100 => log2(7.84 * 100) = log2(784) ≈ 9.6147
      final ev = sensorService.calculateEV(2.8, 1 / 100);
      expect(ev, closeTo(9.6147, 0.001));
    });

    test('calculateEV returns 0 for invalid inputs', () {
      expect(sensorService.calculateEV(0, 1 / 100), 0.0);
      expect(sensorService.calculateEV(2.8, 0), 0.0);
      expect(sensorService.calculateEV(-1, 1 / 100), 0.0);
    });

    test('estimateEVFromLux returns correct value for ISO 100', () {
      // EV100 = log2(Lux / 2.5)
      // Lux=250 => log2(100) ≈ 6.6438
      final ev = sensorService.estimateEVFromLux(250, iso: 100);
      expect(ev, closeTo(6.6438, 0.001));
    });

    test('calculateShutterSpeed returns correct reciprocal speed', () {
      // t = N^2 / 2^EV  =>  N=4, EV=10  =>  16/1024 = 1/64
      final t = sensorService.calculateShutterSpeed(4.0, 10.0);
      expect(t, closeTo(1 / 64, 0.0001));
    });
  });

  group('Calibration offset', () {
    test('calculateEV100 applies calibration offset', () {
      // Raw EV100 = log2(N^2/t) - log2(ISO/100)
      // N=1.8, t=1/1000, ISO=200
      // log2(1.8^2 * 1000) = log2(3240) ≈ 11.6625
      // log2(200/100) = 1
      // Raw EV100 ≈ 10.6625
      // Calibrated = 10.6625 + (-0.7) = 9.9625
      final ev100 = sensorService.calculateEV100(1.8, 1 / 1000, 200);
      final rawEv100 = math.log(math.pow(1.8, 2) / (1 / 1000)) / math.ln2
          - math.log(200 / 100) / math.ln2;
      expect(ev100, closeTo(rawEv100 + SensorService.calibrationOffset, 0.001));
    });

    test('calibrationOffset is negative (compensates iPhone overexposure)', () {
      expect(SensorService.calibrationOffset, lessThan(0));
    });
  });

  group('Lux from EV100 (display)', () {
    test('calculateLuxFromEV100 uses Lux = 2.5 × 2^EV100', () {
      // EV100 = 10 => Lux = 2.5 × 1024 = 2560
      final lux = sensorService.calculateLuxFromEV100(10);
      expect(lux, closeTo(2560, 0.1));
    });

    test('Lux-to-EV and EV-to-Lux round-trip', () {
      const testLux = 5000.0;
      final ev = sensorService.estimateEVFromLux(testLux, iso: 100);
      final roundTripped = sensorService.calculateLuxFromEV100(ev);
      expect(roundTripped, closeTo(testLux, 0.5));
    });
  });

  group('Snap logic – shutter speeds', () {
    test('exact standard speed is unchanged', () {
      expect(SensorService.snapShutterSpeed(1 / 125), closeTo(1 / 125, 1e-9));
      expect(SensorService.snapShutterSpeed(1 / 1000), closeTo(1 / 1000, 1e-9));
      expect(SensorService.snapShutterSpeed(1.0), closeTo(1.0, 1e-9));
    });

    test('non-standard speed snaps to nearest stop', () {
      // 1/1138 is between 1/1000 and 1/2000; closer to 1/1000 in log space
      final snapped = SensorService.snapShutterSpeed(1 / 1138);
      expect(snapped, closeTo(1 / 1000, 1e-9));
    });

    test('very fast speed clamps to 1/4000', () {
      final snapped = SensorService.snapShutterSpeed(1 / 10000);
      expect(snapped, closeTo(1 / 4000, 1e-9));
    });

    test('very slow speed clamps to 30s', () {
      final snapped = SensorService.snapShutterSpeed(60);
      expect(snapped, closeTo(30, 1e-9));
    });

    test('invalid input returns safe default', () {
      expect(SensorService.snapShutterSpeed(0), closeTo(1 / 125, 1e-9));
      expect(SensorService.snapShutterSpeed(-1), closeTo(1 / 125, 1e-9));
      expect(SensorService.snapShutterSpeed(double.nan), closeTo(1 / 125, 1e-9));
    });
  });

  group('Snap logic – apertures', () {
    test('exact standard aperture is unchanged', () {
      expect(SensorService.snapAperture(2.8), 2.8);
      expect(SensorService.snapAperture(1.0), 1.0);
      expect(SensorService.snapAperture(22.0), 22.0);
    });

    test('non-standard aperture snaps to nearest stop', () {
      expect(SensorService.snapAperture(3.2), 2.8); // closer to 2.8 in log space
      expect(SensorService.snapAperture(6.3), 5.6); // closer to 5.6
    });

    test('invalid input returns safe default', () {
      expect(SensorService.snapAperture(0), 2.8);
      expect(SensorService.snapAperture(-1), 2.8);
      expect(SensorService.snapAperture(double.nan), 2.8);
    });
  });
}
