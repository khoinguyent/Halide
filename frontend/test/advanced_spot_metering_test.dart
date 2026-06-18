import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/meter/logic/advanced_spot_metering_engine.dart';
import 'package:frontend/features/meter/logic/preview_coordinate_mapper.dart';
import 'package:frontend/services/sensor_service.dart';

void main() {
  group('AdvancedSpotMeteringEngine', () {
    test('ev100FromLuminance matches log2(L*S/K)', () {
      // L=100 cd/m², S=100, K=12.5 → EV = log2(800) ≈ 9.64
      final ev = AdvancedSpotMeteringEngine.ev100FromLuminance(100);
      expect(ev, closeTo(math.log(800) / math.ln2, 0.01));
    });

    test('evAtIso shifts by log2(iso/100)', () {
      final ev100 = 10.0;
      expect(AdvancedSpotMeteringEngine.evAtIso(ev100, 400), closeTo(12.0, 0.01));
    });

    test('deltaEvToZone boundaries', () {
      expect(AdvancedSpotMeteringEngine.deltaEvToZone(-5.5), 0);
      expect(AdvancedSpotMeteringEngine.deltaEvToZone(-4.5), 1);
      expect(AdvancedSpotMeteringEngine.deltaEvToZone(0), 5);
      expect(AdvancedSpotMeteringEngine.deltaEvToZone(4.5), 9);
      expect(AdvancedSpotMeteringEngine.deltaEvToZone(5.5), 10);
    });

    test('averageEv computes arithmetic mean', () {
      expect(
        AdvancedSpotMeteringEngine.averageEv([10.0, 12.0, 14.0]),
        closeTo(12.0, 0.001),
      );
    });

    test('shutterFromReciprocity: N²/t = S·2^EV/K', () {
      const ev = 10.0;
      const n = 2.8;
      const iso = 100.0;
      final t = AdvancedSpotMeteringEngine.shutterFromReciprocity(
        aperture: n,
        ev: ev,
        iso: iso,
      );
      final lhs = n * n / t;
      final rhs = iso * math.pow(2, ev) / AdvancedSpotMeteringEngine.calibrationK;
      expect(lhs, closeTo(rhs, 0.01));
    });

    test('evFromRelativeLuminance uses log offset', () {
      final ev = AdvancedSpotMeteringEngine.evFromRelativeLuminance(
        relativeLuminance: 0.36,
        evAnchor: 10.0,
        anchorLuminance: 0.18,
      );
      // +1 EV stop (double luminance)
      expect(ev, closeTo(11.0, 0.01));
    });
  });

  group('PreviewCoordinateMapper', () {
    const viewSize = Size(390, 844);
    const sensorSize = Size(480, 640);

    test('center maps to center', () {
      final result = PreviewCoordinateMapper.mapUiToSensor(
        uiTouchPoint: const Offset(195, 422),
        uiViewSize: viewSize,
        sensorImageSize: sensorSize,
        orientation: InputAnalysisOrientation.portraitUp,
      );
      expect(result.dx, closeTo(0.5, 0.05));
      expect(result.dy, closeTo(0.5, 0.05));
    });

    test('round-trip UI → sensor → UI', () {
      const touch = Offset(100, 200);
      final sensor = PreviewCoordinateMapper.mapUiToSensor(
        uiTouchPoint: touch,
        uiViewSize: viewSize,
        sensorImageSize: sensorSize,
        orientation: InputAnalysisOrientation.portraitUp,
      );
      final back = PreviewCoordinateMapper.mapSensorToUi(
        sensorNormalized: sensor,
        uiViewSize: viewSize,
        sensorImageSize: sensorSize,
        orientation: InputAnalysisOrientation.portraitUp,
      );
      expect(back.dx, closeTo(touch.dx, 2));
      expect(back.dy, closeTo(touch.dy, 2));
    });
  });

  group('SensorService luminance EV', () {
    final svc = SensorService();

    test('ev100FromLuminance delegates to K=12.5', () {
      expect(
        svc.ev100FromLuminance(12.5),
        closeTo(AdvancedSpotMeteringEngine.ev100FromLuminance(12.5), 0.001),
      );
    });
  });
}
