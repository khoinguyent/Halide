/// Live-preview matrix (approximation). Saved frames use adaptive C-41 in
/// [applyC41Conversion].
const List<double> orangeMaskPreviewMatrix = [
  -1.62, 0.0, 0.0, 0.0, 255.0,
  0.0, -2.0, 0.0, 0.0, 255.0,
  0.0, 0.0, -2.8, 0.0, 255.0,
  0.0, 0.0, 0.0, 1.0, 0.0,
];

/// Alias used by the HUD [ColorFilter] toggle.
const List<double> orangeMaskInversionMatrix = orangeMaskPreviewMatrix;

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

/// How long (ms) to let the camera AF hunt after requesting focus before
/// locking AE/AF and allowing capture.  Empirically 600–800 ms covers most
/// rear modules for a macro-distance negative on a light table.
const int gyroFocusSettleMs = 700;

/// Low-pass smoothing factor (higher = snappier).
const double gyroSensorLerpAlpha = 0.22;

/// Cap sensor UI updates (~60 fps).
const Duration gyroSensorThrottle = Duration(milliseconds: 16);
