import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

/// Orientation of the camera sensor image relative to the device UI.
enum InputAnalysisOrientation {
  portraitUp,
  portraitDown,
  landscapeLeft,
  landscapeRight,
}

/// Maps between UI touch coordinates and normalized sensor image coordinates.
///
/// Accounts for [BoxFit.cover] cropping and device orientation — mirrors
/// [_MeterFullBleedPreview] aspect math in [meter_view.dart].
class PreviewCoordinateMapper {
  PreviewCoordinateMapper._();

  /// Normalized sensor point (0–1) from a UI touch in the preview stack.
  static Offset mapUiToSensor({
    required Offset uiTouchPoint,
    required Size uiViewSize,
    required Size sensorImageSize,
    required InputAnalysisOrientation orientation,
  }) {
    if (uiViewSize.width <= 0 || uiViewSize.height <= 0) {
      return const Offset(0.5, 0.5);
    }

    // Step 1: UI → normalized view space [0, 1]
    final nx = (uiTouchPoint.dx / uiViewSize.width).clamp(0.0, 1.0);
    final ny = (uiTouchPoint.dy / uiViewSize.height).clamp(0.0, 1.0);

    // Step 2: invert BoxFit.cover crop
    final viewAr = uiViewSize.width / uiViewSize.height;
    final imageAr = sensorImageSize.width / sensorImageSize.height;
    double visibleNx;
    double visibleNy;

    if (imageAr > viewAr) {
      // Image wider than view — horizontal crop
      final scale = viewAr / imageAr;
      final pad = (1.0 - scale) / 2.0;
      visibleNx = pad + nx * scale;
      visibleNy = ny;
    } else {
      // Image taller than view — vertical crop
      final scale = imageAr / viewAr;
      final pad = (1.0 - scale) / 2.0;
      visibleNx = nx;
      visibleNy = pad + ny * scale;
    }

    // Step 3: rotate to sensor-native coordinates
    return _rotateNormalized(Offset(visibleNx, visibleNy), orientation);
  }

  /// UI position for a normalized sensor point (inverse of [mapUiToSensor]).
  static Offset mapSensorToUi({
    required Offset sensorNormalized,
    required Size uiViewSize,
    required Size sensorImageSize,
    required InputAnalysisOrientation orientation,
  }) {
    if (uiViewSize.width <= 0 || uiViewSize.height <= 0) {
      return Offset(uiViewSize.width / 2, uiViewSize.height / 2);
    }

    final unrotated = _unrotateNormalized(sensorNormalized, orientation);

    final viewAr = uiViewSize.width / uiViewSize.height;
    final imageAr = sensorImageSize.width / sensorImageSize.height;
    double nx;
    double ny;

    if (imageAr > viewAr) {
      final scale = viewAr / imageAr;
      final pad = (1.0 - scale) / 2.0;
      nx = (unrotated.dx - pad) / scale;
      ny = unrotated.dy;
    } else {
      final scale = imageAr / viewAr;
      final pad = (1.0 - scale) / 2.0;
      nx = unrotated.dx;
      ny = (unrotated.dy - pad) / scale;
    }

    return Offset(
      nx.clamp(0.0, 1.0) * uiViewSize.width,
      ny.clamp(0.0, 1.0) * uiViewSize.height,
    );
  }

  /// Sensor pixel coordinate from normalized sensor offset.
  static Offset sensorPixelFromNormalized(
    Offset normalized,
    Size sensorImageSize,
  ) {
    return Offset(
      (normalized.dx * sensorImageSize.width).clamp(0, sensorImageSize.width - 1),
      (normalized.dy * sensorImageSize.height).clamp(0, sensorImageSize.height - 1),
    );
  }

  /// Build orientation + display sizes from a live [CameraController].
  static ({
    InputAnalysisOrientation orientation,
    Size sensorImageSize,
    Size uiViewSize,
  }) layoutFromController(
    CameraController controller,
    Size uiViewSize,
  ) {
    final o = _orientationFromController(controller);
    final rawW = controller.value.previewSize?.width ?? 0;
    final rawH = controller.value.previewSize?.height ?? 0;
    final isLandscape = o == InputAnalysisOrientation.landscapeLeft ||
        o == InputAnalysisOrientation.landscapeRight;

    // Display-oriented sensor dimensions (matches preview aspect math).
    final sensorW = isLandscape ? rawW : rawH;
    final sensorH = isLandscape ? rawH : rawW;

    return (
      orientation: o,
      sensorImageSize: Size(
        sensorW > 0 ? sensorW : 640,
        sensorH > 0 ? sensorH : 480,
      ),
      uiViewSize: uiViewSize,
    );
  }

  static InputAnalysisOrientation _orientationFromController(
    CameraController c,
  ) {
    final v = c.value;
    final deviceO = v.isRecordingVideo
        ? v.recordingOrientation!
        : v.previewPauseOrientation ??
            v.lockedCaptureOrientation ??
            v.deviceOrientation;

    switch (deviceO) {
      case DeviceOrientation.portraitUp:
        return InputAnalysisOrientation.portraitUp;
      case DeviceOrientation.portraitDown:
        return InputAnalysisOrientation.portraitDown;
      case DeviceOrientation.landscapeLeft:
        return InputAnalysisOrientation.landscapeLeft;
      case DeviceOrientation.landscapeRight:
        return InputAnalysisOrientation.landscapeRight;
    }
  }

  static Offset _rotateNormalized(Offset p, InputAnalysisOrientation o) {
    final x = p.dx;
    final y = p.dy;
    switch (o) {
      case InputAnalysisOrientation.portraitUp:
        return Offset(x, y);
      case InputAnalysisOrientation.portraitDown:
        return Offset(1 - x, 1 - y);
      case InputAnalysisOrientation.landscapeLeft:
        return Offset(y, 1 - x);
      case InputAnalysisOrientation.landscapeRight:
        return Offset(1 - y, x);
    }
  }

  static Offset _unrotateNormalized(Offset p, InputAnalysisOrientation o) {
    final x = p.dx;
    final y = p.dy;
    switch (o) {
      case InputAnalysisOrientation.portraitUp:
        return Offset(x, y);
      case InputAnalysisOrientation.portraitDown:
        return Offset(1 - x, 1 - y);
      case InputAnalysisOrientation.landscapeLeft:
        return Offset(1 - y, x);
      case InputAnalysisOrientation.landscapeRight:
        return Offset(y, 1 - x);
    }
  }

  /// Display aspect ratio matching [_meterDisplayAspectRatio].
  static double displayAspectRatio(CameraController c) {
    final ar = c.value.aspectRatio;
    if (ar <= 0 || !ar.isFinite) return 3 / 4;
    final o = _orientationFromController(c);
    final isLandscape = o == InputAnalysisOrientation.landscapeLeft ||
        o == InputAnalysisOrientation.landscapeRight;
    return isLandscape ? ar : 1.0 / ar;
  }
}
