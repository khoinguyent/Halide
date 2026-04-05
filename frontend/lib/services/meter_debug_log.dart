import 'halide_debug_log.dart';

/// Meter-specific API; storage is shared with [HalideDebugLog] under channel `Meter`.
class MeterDebugLog {
  MeterDebugLog._();

  static const String _ch = 'Meter';

  static void clear() => HalideDebugLog.clearChannel(_ch);

  static void log(String message) => HalideDebugLog.log(_ch, message);

  static String get text => HalideDebugLog.textForChannel(_ch);

  static int get lineCount => HalideDebugLog.countForChannel(_ch);
}
