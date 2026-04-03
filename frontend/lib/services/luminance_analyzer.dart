import 'dart:typed_data';
import 'package:camera/camera.dart';

class LuminanceAnalyzer {
  /// Calculates the average luminance (0.0 to 1.0) of a [CameraImage].
  /// Supports YUV420 (Android) and BGRA8888 (iOS).
  static double calculateLuminance(CameraImage image) {
    if (image.format.group == ImageFormatGroup.yuv420) {
      return _calculateYUV420Luminance(image);
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      return _calculateBGRA8888Luminance(image);
    }
    return 0.5; // Fallback to middle gray
  }

  static double _calculateYUV420Luminance(CameraImage image) {
    // In YUV420, the first plane is the Y (luminance) plane.
    final Uint8List plane = image.planes[0].bytes;
    int total = 0;
    
    // We sample pixels to save performance (every 4th pixel)
    for (int i = 0; i < plane.length; i += 4) {
      total += plane[i];
    }
    
    final int count = plane.length ~/ 4;
    return (total / count) / 255.0;
  }

  static double _calculateBGRA8888Luminance(CameraImage image) {
    final Uint8List bytes = image.planes[0].bytes;
    int total = 0;
    
    // BGRA format: Bytes are B, G, R, A.
    // Luminance formula: Y = 0.299R + 0.587G + 0.114B
    for (int i = 0; i < bytes.length; i += 16) { // Sample every 4th pixel (4 bytes per pixel)
      final int b = bytes[i];
      final int g = bytes[i + 1];
      final int r = bytes[i + 2];
      
      total += (0.299 * r + 0.587 * g + 0.114 * b).round();
    }
    
    final int count = bytes.length ~/ 16;
    return (total / count) / 255.0;
  }
}
