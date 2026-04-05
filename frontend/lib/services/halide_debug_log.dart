import 'package:flutter/foundation.dart';

class _LogEntry {
  _LogEntry(this.at, this.channel, this.message);
  final DateTime at;
  final String channel;
  final String message;
}

/// In-memory ring buffer for on-device diagnosis (meter, image sync, etc.).
/// Mirrors lines to [debugPrint] with `[HalideDbg][channel]` prefix.
class HalideDebugLog {
  HalideDebugLog._();

  static final List<_LogEntry> _entries = <_LogEntry>[];
  static const int maxEntries = 250;

  static void log(String channel, String message) {
    _entries.add(_LogEntry(DateTime.now(), channel, message));
    while (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
    debugPrint('[HalideDbg][$channel] $message');
  }

  static String _formatLine(_LogEntry e) {
    final ts = e.at.toIso8601String();
    return '$ts  [${e.channel}] ${e.message}';
  }

  /// All channels, newest at bottom (same order as internal buffer).
  static String get allText {
    if (_entries.isEmpty) return '';
    return _entries.map(_formatLine).join('\n');
  }

  static String textForChannel(String channel) {
    final filtered = _entries.where((e) => e.channel == channel);
    if (filtered.isEmpty) return '';
    return filtered.map(_formatLine).join('\n');
  }

  static void clear() => _entries.clear();

  static void clearChannel(String channel) {
    _entries.removeWhere((e) => e.channel == channel);
  }

  static int get lineCount => _entries.length;

  static int countForChannel(String channel) =>
      _entries.where((e) => e.channel == channel).length;
}
