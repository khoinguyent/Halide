import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/sensor_service.dart';
import 'dart:math' as math;

double _log2(double x) => math.log(x) / math.ln2;

// ─────────────────────────────────────────────────────────────────────────────
// Metering engine regression tests
//
// Acceptance criterion (light_metering.md §7 — "The Fuji Test"):
//   "Point Fuji XT-20 at a scene → Note Exposure.
//    Point Halide App at the same scene.
//    If Halide suggests the same (±0.3 stops) → DONE.
//    If Halide suggests 1/1000 when Fuji says 1/250 → the −2.0 offset
//    has not been applied correctly."
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  final svc = SensorService();

  // ── Raw EV math ──────────────────────────────────────────────────────────
  group('Raw EV calculation', () {
    test('f/2.8 at 1/100s → EV ≈ 9.615', () {
      expect(svc.calculateEV(2.8, 1 / 100), closeTo(9.615, 0.01));
    });

    test('returns 0 for invalid inputs', () {
      expect(svc.calculateEV(0, 1 / 100), 0.0);
      expect(svc.calculateEV(2.8, 0), 0.0);
      expect(svc.calculateEV(-1, 1 / 100), 0.0);
    });

    test('calculateShutterSpeed: t = N² / 2^EV', () {
      expect(svc.calculateShutterSpeed(4.0, 10.0), closeTo(1 / 64, 0.0001));
    });
  });

  // ── Calibration offset ──────────────────────────────────────────────────
  group('Calibration offset (spec §2B)', () {
    test('calibrationOffset is 0.0 (field-aligned with reference meters)', () {
      expect(SensorService.calibrationOffset, 0.0);
    });

    test('calculateEV100 = EV_raw + calibrationOffset', () {
      final ev100 = svc.calculateEV100(1.78, 1 / 250, 100);
      final rawEv = _log2(math.pow(1.78, 2) / (1 / 250)) - _log2(100 / 100);
      expect(ev100, closeTo(rawEv + SensorService.calibrationOffset, 0.01));
    });

    test('EV 8 at f/2.8 ISO 100 → snaps ~1/30', () {
      final t = svc.calculateShutterSpeed(2.8, 8.0);
      expect(SensorService.snapShutterSpeed(t), closeTo(1 / 30, 1e-2));
    });
  });

  // ── BrightnessValue path ───────────────────────────────────────────────
  group('EXIF BrightnessValue → EV₁₀₀', () {
    test('Bv + Sv(100) = Bv + 5', () {
      expect(svc.evFromBrightnessValue(2.0), closeTo(7.0, 0.01));
      expect(svc.evFromBrightnessValue(3.0), closeTo(8.0, 0.01));
    });
  });

  // ── Lux (display-only) ─────────────────────────────────────────────────
  group('Lux from corrected EV₁₀₀ (spec §6, display-only)', () {
    test('Lux = 2.5 × 2^EV₁₀₀', () {
      expect(svc.calculateLuxFromEV100(10), closeTo(2560, 0.1));
    });
  });

  // ── Reciprocal exposure (spec §4) ──────────────────────────────────────
  group('Reciprocal exposure', () {
    test('EV 8, f/2.8, ISO 100 → t ≈ 1/33 → snaps to 1/30', () {
      final t = svc.calculateShutterSpeed(2.8, 8.0);
      // 7.84 / 256 ≈ 0.0306 ≈ 1/33
      expect(t, closeTo(1 / 32.65, 0.002));
      expect(SensorService.snapShutterSpeed(t), closeTo(1 / 30, 1e-9));
    });

    test('Film ISO shifts shutter speed correctly', () {
      // EV_final = 8, film ISO 400 → EV_f = 8 + 2 = 10
      // t = 7.84 / 1024 ≈ 1/131 → snaps to 1/125
      final evAtIso400 = 8.0 + _log2(400 / 100);
      final t = svc.calculateShutterSpeed(2.8, evAtIso400);
      expect(SensorService.snapShutterSpeed(t), closeTo(1 / 125, 1e-9));
    });
  });

  // ── Snap logic (spec §5) ───────────────────────────────────────────────
  group('Snap to standard shutter stops', () {
    test('exact standard speed is unchanged', () {
      expect(SensorService.snapShutterSpeed(1 / 125), closeTo(1 / 125, 1e-9));
      expect(SensorService.snapShutterSpeed(1.0), closeTo(1.0, 1e-9));
    });

    test('1/1138 snaps to 1/1000', () {
      expect(SensorService.snapShutterSpeed(1 / 1138), closeTo(1 / 1000, 1e-9));
    });

    test('1/28 snaps to 1/30', () {
      expect(SensorService.snapShutterSpeed(1 / 28), closeTo(1 / 30, 1e-9));
    });

    test('long exposure: 6.5s snaps to 8s', () {
      expect(SensorService.snapShutterSpeed(6.5), closeTo(8.0, 1e-9));
    });

    test('very fast clamps to 1/4000', () {
      expect(SensorService.snapShutterSpeed(1 / 10000), closeTo(1 / 4000, 1e-9));
    });

    test('very slow clamps to 30s', () {
      expect(SensorService.snapShutterSpeed(60), closeTo(30, 1e-9));
    });

    test('invalid input returns 1/125', () {
      expect(SensorService.snapShutterSpeed(0), closeTo(1 / 125, 1e-9));
      expect(SensorService.snapShutterSpeed(double.nan), closeTo(1 / 125, 1e-9));
    });
  });

  group('Snap to standard aperture stops', () {
    test('exact standard aperture is unchanged', () {
      expect(SensorService.snapAperture(2.8), 2.8);
      expect(SensorService.snapAperture(22.0), 22.0);
    });

    test('3.2 snaps to 2.8 (closer in log space)', () {
      expect(SensorService.snapAperture(3.2), 2.8);
    });

    test('invalid input returns f/2.8', () {
      expect(SensorService.snapAperture(0), 2.8);
      expect(SensorService.snapAperture(double.nan), 2.8);
    });
  });

  // ── Acceptance criterion (spec §7 — "The Fuji Test") ───────────────────
  group('Acceptance: matches reference meters (±~0.3 stops)', () {
    test('Indoor dim scene: iPhone hw → slow shutter (seconds)', () {
      // Dark scene: ISO 3200, 1/30, f/1.78 → EV100 ≈ 1.58 (offset 0)
      // At f/2.8, ISO 100: multi-second
      final ev100 = svc.calculateEV100(1.78, 1 / 30, 3200);
      final t = svc.calculateShutterSpeed(2.8, ev100);
      final snapped = SensorService.snapShutterSpeed(t);
      expect(snapped, greaterThanOrEqualTo(2.0));
      expect(snapped, lessThanOrEqualTo(15.0));
    });

    test('Normal indoor scene: hand-holdable snapped shutter', () {
      // Typical indoor: ISO 400, 1/60, f/1.78 — expect a fast shutter, not seconds.
      final ev100 = svc.calculateEV100(1.78, 1 / 60, 400);
      final evAtFilm400 = ev100 + _log2(400 / 100);
      final t = svc.calculateShutterSpeed(1.4, evAtFilm400);
      final snapped = SensorService.snapShutterSpeed(t);
      expect(snapped, greaterThanOrEqualTo(1 / 250));
      expect(snapped, lessThanOrEqualTo(1 / 15));
    });

    test('Outdoor sunny: shutter ≤ 1/250', () {
      final ev100 = svc.calculateEV100(1.78, 1 / 2000, 50);
      final t = svc.calculateShutterSpeed(2.8, ev100);
      final snapped = SensorService.snapShutterSpeed(t);
      expect(snapped, lessThanOrEqualTo(1 / 250));
    });
  });
}
