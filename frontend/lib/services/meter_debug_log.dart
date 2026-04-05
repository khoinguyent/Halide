import 'package:flutter/foundation.dart';

/// Ring buffer of metering debug lines for on-device diagnosis.
/// View in Xcode console (debugPrint) or copy from the in-app debug sheet (staging/debug).
class MeterDebugLog {
  MeterDebugLog._();

  static final List<String> _lines = <String>[];
  static const int maxLines = 120;

  static void clear() {
    _lines.clear();
  }

  static void log(String message) {
    final ts = DateTime.now().toIso8601String();
    final line = '$ts  $message';
    _lines.add(line);
    while (_lines.length > maxLines) {
      _lines.removeAt(0);
    }
    debugPrint('[MeterDbg] $line');
  }

  static String get text => _lines.join('\n');

  static int get lineCount => _lines.length;
}
