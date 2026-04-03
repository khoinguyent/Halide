import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
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

  MeterState({
    this.lux = 0.0,
    this.evBase = 0.0,
    this.aperture = 2.8,
    this.shutterSpeed = 1 / 100,
    this.iso = 100,
    this.isLocked = false,
    this.evComp = 0.0,
    this.lastChanged = ExposureControl.aperture,
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
    );
  }
}

enum ExposureControl { aperture, shutter }

class MeterNotifier extends Notifier<MeterState> {
  final SensorService _sensorService = SensorService();
  StreamSubscription<double>? _luxSub;

  @override
  MeterState build() {
    _luxSub ??= _sensorService.luxStream.listen((lux) {
      final current = state;
      if (!current.isLocked) {
        final evBase = _sensorService.estimateEVFromLux(lux, iso: current.iso);
        state = _recalculateFrom(
          current.copyWith(lux: lux, evBase: evBase),
        );
      } else {
        state = current.copyWith(lux: lux);
      }
    });
    ref.onDispose(() {
      _luxSub?.cancel();
      _luxSub = null;
    });
    return MeterState();
  }

  void updateAperture(double aperture) {
    if (state.isLocked) return;
    final next = state.copyWith(aperture: aperture, lastChanged: ExposureControl.aperture);
    state = _recalculateFrom(next);
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
    state = _recalculateFrom(state.copyWith(shutterSpeed: shutterSpeed, lastChanged: ExposureControl.shutter));
  }

  void updateFromHardware({
    required double iso,
    required double shutter,
    required double aperture,
  }) {
    if (state.isLocked) return;

    final rawEv = _sensorService.calculateEV(aperture, shutter);
    final ev100 = _sensorService.calculateEV100(aperture, shutter, iso);
    final lux = _sensorService.calculateLuxFromEV100(ev100);

    debugPrint('[Meter] hw: f/$aperture  t=1/${(1/shutter).round()}  ISO=$iso'
        '  rawEV=${rawEv.toStringAsFixed(2)}'
        '  ev100(calibrated)=${ev100.toStringAsFixed(2)}'
        '  lux=${lux.toStringAsFixed(0)}');

    state = _recalculateFrom(
      state.copyWith(lux: lux, evBase: ev100),
    );
  }

  void updateLuminance(double luminance) {
    if (state.isLocked) return;

    final evBase = _sensorService.estimateEVFromLuminance(luminance);
    final lux = _sensorService.calculateLuxFromEV100(evBase);

    state = _recalculateFrom(
      state.copyWith(lux: lux, evBase: evBase),
    );
  }

  void toggleLock() {
    state = state.copyWith(isLocked: !state.isLocked);
  }

  MeterState _recalculateFrom(MeterState current) {
    final evAtUserIso = current.evBase
        + (math.log(current.iso / 100.0) / math.ln2)
        + current.evComp;

    if (current.lastChanged == ExposureControl.shutter) {
      final a = _apertureFromShutterAndEv(current.shutterSpeed, evAtUserIso);
      final snapped = SensorService.snapAperture(a);
      return current.copyWith(aperture: snapped);
    }

    final rawShutter = _sensorService.calculateShutterSpeed(current.aperture, evAtUserIso);
    final snappedShutter = SensorService.snapShutterSpeed(rawShutter);
    return current.copyWith(shutterSpeed: snappedShutter);
  }

  double _apertureFromShutterAndEv(double shutterSpeed, double ev) {
    final t = shutterSpeed <= 0 ? 1 / 100 : shutterSpeed;
    return math.sqrt(t * math.pow(2, ev));
  }
}

final meterProvider = NotifierProvider<MeterNotifier, MeterState>(MeterNotifier.new);
