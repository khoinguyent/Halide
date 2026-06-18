import 'package:flutter/foundation.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Manages system brightness override and screen wake lock for Light Table mode.
class LightTableHardwareController {
  double? _cachedBrightness;

  /// Caches current brightness, forces maximum, and enables wake lock.
  Future<void> activate() async {
    await Future.wait([
      setMaxBrightness(),
      _enableWakeLock(),
    ]);
  }

  /// Restores cached brightness and releases wake lock.
  Future<void> deactivate() async {
    await Future.wait([
      restoreBrightness(),
      _disableWakeLock(),
    ]);
  }

  Future<void> setMaxBrightness() async {
    try {
      final brightness = ScreenBrightness();
      _cachedBrightness = await brightness.application;
      try {
        await brightness.setSystemScreenBrightness(1.0);
      } catch (_) {
        await brightness.setApplicationScreenBrightness(1.0);
      }
    } catch (e) {
      debugPrint('Failed to force maximum system brightness: $e');
    }
  }

  Future<void> restoreBrightness() async {
    try {
      final brightness = ScreenBrightness();
      final cached = _cachedBrightness;
      if (cached != null) {
        await brightness.setApplicationScreenBrightness(cached);
      } else {
        await brightness.resetApplicationScreenBrightness();
      }
    } catch (e) {
      debugPrint('Failed to restore system brightness: $e');
    }
  }

  Future<void> _enableWakeLock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Failed to enable wake lock: $e');
    }
  }

  Future<void> _disableWakeLock() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('Failed to disable wake lock: $e');
    }
  }
}
