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

  static const List<double> _apertureStops = [
    1.4,
    2.0,
    2.8,
    4.0,
    5.6,
    8.0,
    11.0,
    16.0,
    22.0,
  ];

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
    final evBase = _sensorService.estimateEVFromLux(state.lux, iso: iso);
    final next = state.copyWith(iso: iso, evBase: evBase);
    state = _recalculateFrom(next);
  }

  void updateEVComp(double evComp) {
    if (state.isLocked) return;
    final next = state.copyWith(evComp: evComp);
    state = _recalculateFrom(next);
  }

  void updateShutterSpeed(double shutterSpeed) {
    if (state.isLocked) return;
    final next = state.copyWith(shutterSpeed: shutterSpeed, lastChanged: ExposureControl.shutter);
    state = _recalculateFrom(next);
  }

  void toggleLock() {
    state = state.copyWith(isLocked: !state.isLocked);
  }

  MeterState _recalculateFrom(MeterState current) {
    final ev = current.ev;
    if (ev <= 0) {
      return current.copyWith(
        shutterSpeed: current.shutterSpeed <= 0 ? 1 / 100 : current.shutterSpeed,
        aperture: current.aperture <= 0 ? 2.8 : current.aperture,
      );
    }

    if (current.lastChanged == ExposureControl.shutter) {
      final a = _apertureFromShutterAndEv(current.shutterSpeed, ev);
      final snapped = _snapAperture(a);
      return current.copyWith(aperture: snapped);
    }

    // Default: keep aperture fixed, compute shutter speed.
    final shutter = _sensorService.calculateShutterSpeed(current.aperture, ev);
    return current.copyWith(shutterSpeed: shutter);
  }

  double _apertureFromShutterAndEv(double shutterSpeed, double ev) {
    // From t = N^2 / 2^EV => N = sqrt(t * 2^EV)
    final t = shutterSpeed <= 0 ? 1 / 100 : shutterSpeed;
    return math.sqrt(t * math.pow(2, ev));
  }

  double _snapAperture(double value) {
    final v = value.isFinite ? value : 2.8;
    double best = _apertureStops.first;
    double bestDist = (v - best).abs();
    for (final s in _apertureStops.skip(1)) {
      final d = (v - s).abs();
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }
}

final meterProvider = NotifierProvider<MeterNotifier, MeterState>(MeterNotifier.new);
