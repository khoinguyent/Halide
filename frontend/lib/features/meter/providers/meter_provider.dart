import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/meter_debug_log.dart';
import '../../../services/sensor_service.dart';
import 'dart:math' as math;

class MeterState {
  final double lux;
  final double aperture;
  final double shutterSpeed;
  final double iso;
  final bool isLocked;
  final double evComp;
  final double evBase;
  final ExposureControl lastChanged;
  final bool isAeStable;

  MeterState({
    this.lux = 0.0,
    this.evBase = 0.0,
    this.aperture = 2.8,
    this.shutterSpeed = 1 / 100,
    this.iso = 100,
    this.isLocked = false,
    this.evComp = 0.0,
    this.lastChanged = ExposureControl.aperture,
    this.isAeStable = false,
  });

  double get ev => evBase + evComp;

  MeterState copyWith({
    double? lux,
    double? evBase,
    double? aperture,
    double? shutterSpeed,
    double? iso,
    bool? isLocked,
    double? evComp,
    ExposureControl? lastChanged,
    bool? isAeStable,
  }) {
    return MeterState(
      lux: lux ?? this.lux,
      evBase: evBase ?? this.evBase,
      aperture: aperture ?? this.aperture,
      shutterSpeed: shutterSpeed ?? this.shutterSpeed,
      iso: iso ?? this.iso,
      isLocked: isLocked ?? this.isLocked,
      evComp: evComp ?? this.evComp,
      lastChanged: lastChanged ?? this.lastChanged,
      isAeStable: isAeStable ?? this.isAeStable,
    );
  }
}

enum ExposureControl { aperture, shutter }

class MeterNotifier extends Notifier<MeterState> {
  final SensorService _sensorService = SensorService();

  // ── EMA smoothing (prevent jumpiness) ──────────────────────────────────
  double? _smoothedEv;

  @override
  MeterState build() => MeterState();

  // ── User control updates ───────────────────────────────────────────────

  void updateAperture(double aperture) {
    if (state.isLocked) return;
    state = _recalculateFrom(
      state.copyWith(aperture: aperture, lastChanged: ExposureControl.aperture),
    );
  }

  void updateISO(double iso) {
    if (state.isLocked) return;
    state = _recalculateFrom(state.copyWith(iso: iso));
  }

  void updateEVComp(double evComp) {
    if (state.isLocked) return;
    state = _recalculateFrom(state.copyWith(evComp: evComp));
  }

  void updateShutterSpeed(double shutterSpeed) {
    if (state.isLocked) return;
    state = _recalculateFrom(
      state.copyWith(shutterSpeed: shutterSpeed, lastChanged: ExposureControl.shutter),
    );
  }

  // ── Primary metering path: camera hardware metadata ────────────────────
  //
  //   1. Compute EV₁₀₀ from hardware auto-exposure (aperture, shutter, ISO).
  //   2. Apply −2.0 calibration offset (spec §2B).
  //   3. EMA-smooth — more aggressive when AE is still adjusting.
  //   4. Derive Lux from corrected EV (display-only, spec §6).
  //   5. Reciprocal exposure → film shutter speed.
  //   6. Snap to standard stop at display step only.
  //
  //   No ambient Lux sensor — it measures INCIDENT light (ceiling),
  //   not REFLECTED light (subject).  See spec §1: "We cannot rely on
  //   raw Lux sensors (blocked on iOS)."

  void updateFromHardware({
    required double iso,
    required double shutter,
    required double aperture,
    bool isAdjusting = false,
    double targetOffset = 0.0,
    String? nativeDeviceId,
  }) {
    if (state.isLocked) return;

    if (!_isValidHardwareSample(iso, shutter, aperture)) {
      MeterDebugLog.log(
        'SKIP invalid sample: ISO=$iso t=$shutter N=$aperture '
        '(native needs same AVCaptureDevice as Flutter camera — check setActiveCaptureDevice)',
      );
      return;
    }

    // AE stability: track for UI indicator, but NEVER block readings.
    // Relax |targetOffset| — iPhone often reports >1.5 EV while still usable.
    final isFrameStable = !isAdjusting && targetOffset.abs() <= 3.0;

    // Phase A + B: raw EV₁₀₀ with −2.0 calibration (spec §2)
    final ev100 = _sensorService.calculateEV100(aperture, shutter, iso);

    // EMA smoothing (center-weighted average over time)
    // Stable AE → fast response (α=0.35); adjusting → damped (α=0.10)
    final alpha = isFrameStable ? 0.35 : 0.10;
    _smoothedEv = _smoothedEv == null
        ? ev100
        : alpha * ev100 + (1 - alpha) * _smoothedEv!;

    // Lux derived from corrected EV, not from sensor (spec §6)
    final lux = _sensorService.calculateLuxFromEV100(_smoothedEv!);

    final line =
        'f/${aperture.toStringAsFixed(2)} t=${_fmtShutter(shutter)} ISO=${iso.toStringAsFixed(0)} '
        'ev100=${ev100.toStringAsFixed(2)} smoothed=${_smoothedEv!.toStringAsFixed(2)} '
        'stable=$isFrameStable adj=$isAdjusting tgtOff=${targetOffset.toStringAsFixed(2)} '
        'lux≈${lux.toStringAsFixed(0)}'
        '${nativeDeviceId != null ? ' uid=$nativeDeviceId' : ''}';
    debugPrint('[Meter] hw: $line');
    MeterDebugLog.log(line);

    state = _recalculateFrom(
      state.copyWith(lux: lux, evBase: _smoothedEv!, isAeStable: isFrameStable),
    );
  }

  /// Rejects NaN/∞ and zero ISO/shutter/aperture — otherwise [calculateEV100] becomes 0 → bogus 8s at f/2.8.
  static bool _isValidHardwareSample(double iso, double shutter, double aperture) {
    if (!iso.isFinite || !shutter.isFinite || !aperture.isFinite) return false;
    if (iso <= 0 || shutter <= 0 || aperture <= 0) return false;
    if (shutter < 1e-9) return false;
    return true;
  }

  /// Resets to Aperture Priority: compute shutter from the current scene EV
  /// and the user-selected aperture.  Called when the user taps the meter circle.
  void resetToAperturePriority() {
    if (state.isLocked) return;
    state = _recalculateFrom(
      state.copyWith(lastChanged: ExposureControl.aperture),
    );
  }

  void toggleLock() {
    if (!state.isLocked) {
      state = state.copyWith(isLocked: true);
    } else {
      _smoothedEv = null;
      state = state.copyWith(isLocked: false, isAeStable: false);
    }
  }

  // ── Reciprocal exposure (spec §4) ──────────────────────────────────────

  MeterState _recalculateFrom(MeterState current) {
    // EV_f = EV_final + log₂(ISO_film / 100) + evComp
    final evAtFilmIso = current.evBase
        + _log2(current.iso / 100.0)
        + current.evComp;

    if (current.lastChanged == ExposureControl.shutter) {
      final rawAperture = _apertureFromShutterAndEv(current.shutterSpeed, evAtFilmIso);
      return current.copyWith(aperture: SensorService.snapAperture(rawAperture));
    }

    // t = N² / 2^EV_f   (spec §4)
    final rawShutter = _sensorService.calculateShutterSpeed(current.aperture, evAtFilmIso);
    return current.copyWith(shutterSpeed: SensorService.snapShutterSpeed(rawShutter));
  }

  double _apertureFromShutterAndEv(double shutterSpeed, double ev) {
    final t = shutterSpeed <= 0 ? 1 / 100 : shutterSpeed;
    return math.sqrt(t * math.pow(2, ev));
  }

  static double _log2(double x) => math.log(x) / math.ln2;

  static String _fmtShutter(double s) =>
      s >= 1 ? '${s.toStringAsFixed(1)}s' : '1/${(1 / s).round()}';
}

final meterProvider = NotifierProvider<MeterNotifier, MeterState>(MeterNotifier.new);
