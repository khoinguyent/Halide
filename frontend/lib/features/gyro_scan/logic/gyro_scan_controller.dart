import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../presentation/widgets/gyro_hud_overlay.dart';
import 'gyro_scan_constants.dart';

/// Smoothed gyro / accelerometer state for the scan HUD.
class GyroScanSensorSnapshot {
  final double pitchDeg;
  final double rollDeg;
  final double thetaDeg;
  final bool isAligned;
  final GyroFeedback feedback;
  final Offset dotOffset;
  final bool snapToCenter;

  const GyroScanSensorSnapshot({
    required this.pitchDeg,
    required this.rollDeg,
    required this.thetaDeg,
    required this.isAligned,
    required this.feedback,
    required this.dotOffset,
    required this.snapToCenter,
  });

  static const initial = GyroScanSensorSnapshot(
    pitchDeg: 0,
    rollDeg: 0,
    thetaDeg: 999,
    isAligned: false,
    feedback: GyroFeedback.locked,
    dotOffset: Offset.zero,
    snapToCenter: false,
  );
}

/// Listens to device motion, smooths jitter, and exposes throttled HUD state.
class GyroScanController extends ChangeNotifier {
  GyroScanController();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  double _rawPitch = 0;
  double _rawRoll = 0;
  double _smoothPitch = 0;
  double _smoothRoll = 0;
  bool _hasSmoothSample = false;

  DateTime? _alignedSince;
  DateTime? _lastEmit;
  GyroFeedback? _lastFeedback;

  GyroScanSensorSnapshot _snapshot = GyroScanSensorSnapshot.initial;
  GyroScanSensorSnapshot get snapshot => _snapshot;

  bool _disposed = false;

  void start() {
    _accelSub?.cancel();
    _gyroSub?.cancel();

    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onAccelerometer);

    // Gyroscope subscription keeps the sensor pipeline warm on devices that
    // fuse motion data; pitch/roll are derived from gravity (accelerometer).
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((_) {});
  }

  void _onAccelerometer(AccelerometerEvent event) {
    if (_disposed) return;

    final x = event.x;
    final y = event.y;
    final z = event.z;
    _rawPitch = math.atan2(x, math.sqrt(y * y + z * z)) * 180 / math.pi;
    _rawRoll = math.atan2(y, math.sqrt(x * x + z * z)) * 180 / math.pi;

    if (!_hasSmoothSample) {
      _smoothPitch = _rawPitch;
      _smoothRoll = _rawRoll;
      _hasSmoothSample = true;
    } else {
      _smoothPitch = _lerp(_smoothPitch, _rawPitch, gyroSensorLerpAlpha);
      _smoothRoll = _lerp(_smoothRoll, _rawRoll, gyroSensorLerpAlpha);
    }

    final theta = math.sqrt(_smoothPitch * _smoothPitch + _smoothRoll * _smoothRoll);
    final now = DateTime.now();

    final feedback = _feedbackForTheta(theta);
    if (feedback == GyroFeedback.ready && _lastFeedback != GyroFeedback.ready) {
      HapticFeedback.lightImpact();
    }
    _lastFeedback = feedback;

    bool isAligned = false;
    if (theta <= gyroReadyThetaDeg) {
      _alignedSince ??= now;
      isAligned = now.difference(_alignedSince!).inMilliseconds >= gyroStableCaptureMs;
    } else {
      _alignedSince = null;
    }

    final snapToCenter = feedback == GyroFeedback.ready;
    final dotOffset = snapToCenter ? Offset.zero : _dotOffset(_smoothPitch, _smoothRoll);

    final next = GyroScanSensorSnapshot(
      pitchDeg: _smoothPitch,
      rollDeg: _smoothRoll,
      thetaDeg: theta,
      isAligned: isAligned,
      feedback: feedback,
      dotOffset: dotOffset,
      snapToCenter: snapToCenter,
    );

    final last = _lastEmit;
    if (last != null && now.difference(last) < gyroSensorThrottle) {
      _snapshot = next;
      return;
    }
    _lastEmit = now;
    _snapshot = next;
    notifyListeners();
  }

  static GyroFeedback _feedbackForTheta(double thetaDeg) {
    if (thetaDeg > gyroLockedThetaDeg) return GyroFeedback.locked;
    if (thetaDeg > gyroReadyThetaDeg) return GyroFeedback.guiding;
    return GyroFeedback.ready;
  }

  static Offset _dotOffset(double pitchDeg, double rollDeg) {
    final scaleX = (pitchDeg / gyroMaxPitchRollDeg).clamp(-1.0, 1.0);
    final scaleY = (rollDeg / gyroMaxPitchRollDeg).clamp(-1.0, 1.0);
    return Offset(scaleX * gyroMaxDotOffsetPx, scaleY * gyroMaxDotOffsetPx);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Call after a successful capture so the next frame must re-stabilize.
  void resetAlignment() {
    _alignedSince = null;
    _lastFeedback = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
    super.dispose();
  }
}
