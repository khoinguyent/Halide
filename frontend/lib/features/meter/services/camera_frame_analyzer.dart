import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../logic/advanced_spot_metering_engine.dart';

/// Pixel-domain luminance sampling for spot / zone metering.
class LuminanceAnalyzer {
  static double calculateLuminance(SerializableFrame frame) {
    if (frame.isBgra) {
      return _calculateBGRA8888Luminance(frame);
    }
    return _calculateYUV420Luminance(frame);
  }

  static double sampleRegionLuminance(
    SerializableFrame frame,
    int centerX,
    int centerY, {
    int halfSize = AdvancedSpotMeteringEngine.pinSampleRadius,
  }) {
    if (frame.isBgra) {
      return _sampleBGRA8888Region(frame, centerX, centerY, halfSize);
    }
    return _sampleYUV420Region(frame, centerX, centerY, halfSize);
  }

  static List<int> buildZoneColorGrid({
    required SerializableFrame frame,
    required double evTarget,
    required double evAnchor,
    required double anchorLuminance,
    int gridWidth = AdvancedSpotMeteringEngine.zoneGridWidth,
    int gridHeight = AdvancedSpotMeteringEngine.zoneGridHeight,
  }) {
    final w = frame.width;
    final h = frame.height;
    final colors = List<int>.filled(gridWidth * gridHeight, 0);

    for (var gy = 0; gy < gridHeight; gy++) {
      for (var gx = 0; gx < gridWidth; gx++) {
        final px = ((gx + 0.5) / gridWidth * w).floor().clamp(0, w - 1);
        final py = ((gy + 0.5) / gridHeight * h).floor().clamp(0, h - 1);
        final y = sampleRegionLuminance(frame, px, py, halfSize: 2);
        final ev = AdvancedSpotMeteringEngine.evFromRelativeLuminance(
          relativeLuminance: y,
          evAnchor: evAnchor,
          anchorLuminance: anchorLuminance,
        );
        final zone = AdvancedSpotMeteringEngine.deltaEvToZone(ev - evTarget);
        colors[gy * gridWidth + gx] =
            AdvancedSpotMeteringEngine.zoneColors[zone].toARGB32();
      }
    }
    return colors;
  }

  static double _calculateYUV420Luminance(SerializableFrame frame) {
    final bytes = frame.planeBytes;
    int total = 0;
    for (int i = 0; i < bytes.length; i += 4) {
      total += bytes[i];
    }
    final count = bytes.length ~/ 4;
    return count == 0 ? 0.5 : (total / count) / 255.0;
  }

  static double _calculateBGRA8888Luminance(SerializableFrame frame) {
    final bytes = frame.planeBytes;
    int total = 0;
    for (int i = 0; i < bytes.length; i += 16) {
      final b = bytes[i];
      final g = bytes[i + 1];
      final r = bytes[i + 2];
      total += (0.299 * r + 0.587 * g + 0.114 * b).round();
    }
    final count = bytes.length ~/ 16;
    return count == 0 ? 0.5 : (total / count) / 255.0;
  }

  static double _sampleYUV420Region(
    SerializableFrame frame,
    int centerX,
    int centerY,
    int halfSize,
  ) {
    final bytes = frame.planeBytes;
    final rowStride = frame.bytesPerRow;
    final w = frame.width;
    final h = frame.height;

    int total = 0;
    int count = 0;
    final x0 = (centerX - halfSize).clamp(0, w - 1);
    final x1 = (centerX + halfSize).clamp(0, w - 1);
    final y0 = (centerY - halfSize).clamp(0, h - 1);
    final y1 = (centerY + halfSize).clamp(0, h - 1);

    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final idx = y * rowStride + x;
        if (idx < bytes.length) {
          total += bytes[idx];
          count++;
        }
      }
    }
    if (count == 0) return 0.5;
    return (total / count) / 255.0;
  }

  static double _sampleBGRA8888Region(
    SerializableFrame frame,
    int centerX,
    int centerY,
    int halfSize,
  ) {
    final bytes = frame.planeBytes;
    final rowStride = frame.bytesPerRow;
    final w = frame.width;
    final h = frame.height;

    int total = 0;
    int count = 0;
    final x0 = (centerX - halfSize).clamp(0, w - 1);
    final x1 = (centerX + halfSize).clamp(0, w - 1);
    final y0 = (centerY - halfSize).clamp(0, h - 1);
    final y1 = (centerY + halfSize).clamp(0, h - 1);

    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final idx = y * rowStride + x * 4;
        if (idx + 2 < bytes.length) {
          final b = bytes[idx];
          final g = bytes[idx + 1];
          final r = bytes[idx + 2];
          total += (0.299 * r + 0.587 * g + 0.114 * b).round();
          count++;
        }
      }
    }
    if (count == 0) return 0.5;
    return (total / count) / 255.0;
  }
}

/// Copy of camera frame bytes safe to pass across isolates.
class SerializableFrame {
  final Uint8List planeBytes;
  final int width;
  final int height;
  final int bytesPerRow;
  final bool isBgra;

  const SerializableFrame({
    required this.planeBytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.isBgra,
  });

  factory SerializableFrame.fromCameraImage(CameraImage image) {
    final plane = image.planes.first;
    final isBgra = image.format.group == ImageFormatGroup.bgra8888;
    return SerializableFrame(
      planeBytes: Uint8List.fromList(plane.bytes),
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      isBgra: isBgra,
    );
  }
}

class FrameAnalysisRequest {
  final SerializableFrame frame;
  final double evTarget;
  final double evAnchor;
  final double anchorLuminance;
  final List<({String id, double nx, double ny})> pins;
  final bool buildZoneGrid;

  const FrameAnalysisRequest({
    required this.frame,
    required this.evTarget,
    required this.evAnchor,
    required this.anchorLuminance,
    required this.pins,
    this.buildZoneGrid = false,
  });
}

class FrameAnalysisResult {
  final List<int>? zoneColors;
  final List<({String id, double ev})> pinEvs;
  final double centerLuminance;

  const FrameAnalysisResult({
    this.zoneColors,
    required this.pinEvs,
    required this.centerLuminance,
  });
}

FrameAnalysisResult analyzeFrameInIsolate(FrameAnalysisRequest req) {
  final frame = req.frame;
  final w = frame.width;
  final h = frame.height;
  final cx = w ~/ 2;
  final cy = h ~/ 2;
  final centerY = LuminanceAnalyzer.sampleRegionLuminance(frame, cx, cy);

  List<int>? zoneColors;
  if (req.buildZoneGrid && req.evTarget.isFinite) {
    zoneColors = LuminanceAnalyzer.buildZoneColorGrid(
      frame: frame,
      evTarget: req.evTarget,
      evAnchor: req.evAnchor,
      anchorLuminance: req.anchorLuminance,
    );
  }

  final pinEvs = <({String id, double ev})>[];
  for (final pin in req.pins) {
    final px = (pin.nx * w).floor().clamp(0, w - 1);
    final py = (pin.ny * h).floor().clamp(0, h - 1);
    final y = LuminanceAnalyzer.sampleRegionLuminance(frame, px, py);
    final ev = AdvancedSpotMeteringEngine.evFromRelativeLuminance(
      relativeLuminance: y,
      evAnchor: req.evAnchor,
      anchorLuminance: req.anchorLuminance,
    );
    pinEvs.add((id: pin.id, ev: ev));
  }

  return FrameAnalysisResult(
    zoneColors: zoneColors,
    pinEvs: pinEvs,
    centerLuminance: centerY,
  );
}

Future<FrameAnalysisResult> analyzeFrame({
  required CameraImage image,
  required double evTarget,
  required double evAnchor,
  required double anchorLuminance,
  required List<({String id, double nx, double ny})> pins,
  bool buildZoneGrid = false,
}) {
  return compute(
    analyzeFrameInIsolate,
    FrameAnalysisRequest(
      frame: SerializableFrame.fromCameraImage(image),
      evTarget: evTarget,
      evAnchor: evAnchor,
      anchorLuminance: anchorLuminance,
      pins: pins,
      buildZoneGrid: buildZoneGrid,
    ),
  );
}
