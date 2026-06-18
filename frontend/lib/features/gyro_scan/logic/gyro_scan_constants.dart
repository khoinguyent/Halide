/// Calibrated 4×5 color matrix: invert channels and offset the orange/amber
/// mask of standard color-negative film for a live “positive” preview.
const List<double> orangeMaskInversionMatrix = [
  -1.0, 0.0, 0.0, 0.0, 255.0, // Red
  0.0, -1.2, 0.0, 0.0, 230.0, // Green — balance cyan shift
  0.0, 0.0, -1.8, 0.0, 190.0, // Blue — neutralize amber base
  0.0, 0.0, 0.0, 1.0, 0.0, // Alpha
];

/// Target ring radius (logical pixels).
const double gyroTargetRingRadius = 48.0;

/// Map ±[maxPitchRollDeg] of tilt to ±[maxDotOffsetPx] from screen center.
const double gyroMaxPitchRollDeg = 10.0;
const double gyroMaxDotOffsetPx = 100.0;

/// Alignment thresholds (degrees).
const double gyroLockedThetaDeg = 1.0;
const double gyroReadyThetaDeg = 0.15;
const double gyroAeAfLockThetaDeg = 0.50;
const int gyroStableCaptureMs = 300;

/// Low-pass smoothing factor (higher = snappier).
const double gyroSensorLerpAlpha = 0.22;

/// Cap sensor UI updates (~60 fps).
const Duration gyroSensorThrottle = Duration(milliseconds: 16);
