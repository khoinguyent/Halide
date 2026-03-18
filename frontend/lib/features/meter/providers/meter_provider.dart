import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/sensor_service.dart';

class MeterState {
  final double lux;
  final double ev;
  final double aperture;
  final double shutterSpeed;
  final double iso;
  final bool isLocked;

  MeterState({
    this.lux = 0.0,
    this.ev = 0.0,
    this.aperture = 2.8,
    this.shutterSpeed = 1 / 100,
    this.iso = 100,
    this.isLocked = false,
  });

  MeterState copyWith({
    double? lux,
    double? ev,
    double? aperture,
    double? shutterSpeed,
    double? iso,
    bool? isLocked,
  }) {
    return MeterState(
      lux: lux ?? this.lux,
      ev: ev ?? this.ev,
      aperture: aperture ?? this.aperture,
      shutterSpeed: shutterSpeed ?? this.shutterSpeed,
      iso: iso ?? this.iso,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

class MeterNotifier extends StateNotifier<MeterState> {
  final SensorService _sensorService = SensorService();

  MeterNotifier() : super(MeterState()) {
    _init();
  }

  void _init() {
    _sensorService.luxStream.listen((lux) {
      if (!state.isLocked) {
        final ev = _sensorService.estimateEVFromLux(lux, iso: state.iso);
        final shutterSpeed = _sensorService.calculateShutterSpeed(state.aperture, ev);
        state = state.copyWith(lux: lux, ev: ev, shutterSpeed: shutterSpeed);
      } else {
        state = state.copyWith(lux: lux);
      }
    });
  }

  void updateAperture(double aperture) {
    if (state.isLocked) return;
    final shutterSpeed = _sensorService.calculateShutterSpeed(aperture, state.ev);
    state = state.copyWith(aperture: aperture, shutterSpeed: shutterSpeed);
  }

  void updateISO(double iso) {
    if (state.isLocked) return;
    final ev = _sensorService.estimateEVFromLux(state.lux, iso: iso);
    final shutterSpeed = _sensorService.calculateShutterSpeed(state.aperture, ev);
    state = state.copyWith(iso: iso, ev: ev, shutterSpeed: shutterSpeed);
  }

  void toggleLock() {
    state = state.copyWith(isLocked: !state.isLocked);
  }
}

final meterProvider = StateNotifierProvider<MeterNotifier, MeterState>((ref) {
  return MeterNotifier();
});
