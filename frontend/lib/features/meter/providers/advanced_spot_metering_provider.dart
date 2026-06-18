import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/sensor_service.dart';
import '../logic/advanced_spot_metering_engine.dart';
import '../services/camera_frame_analyzer.dart';

/// A placed metering pin in normalized sensor coordinates (0–1).
class MeteringPin {
  final String id;
  final double normalizedX;
  final double normalizedY;
  final double? ev;

  const MeteringPin({
    required this.id,
    required this.normalizedX,
    required this.normalizedY,
    this.ev,
  });

  MeteringPin copyWith({
    double? normalizedX,
    double? normalizedY,
    double? ev,
    bool clearEv = false,
  }) {
    return MeteringPin(
      id: id,
      normalizedX: normalizedX ?? this.normalizedX,
      normalizedY: normalizedY ?? this.normalizedY,
      ev: clearEv ? null : (ev ?? this.ev),
    );
  }
}

class AdvancedSpotMeteringState {
  final bool zoneOverlayEnabled;
  final bool multiSpotEnabled;
  final List<MeteringPin> pins;
  final List<int>? zoneColorGrid;
  final int zoneGridWidth;
  final int zoneGridHeight;
  final double? averageEv;
  final double anchorLuminance;
  final bool isAnalyzing;

  const AdvancedSpotMeteringState({
    this.zoneOverlayEnabled = false,
    this.multiSpotEnabled = false,
    this.pins = const [],
    this.zoneColorGrid,
    this.zoneGridWidth = AdvancedSpotMeteringEngine.zoneGridWidth,
    this.zoneGridHeight = AdvancedSpotMeteringEngine.zoneGridHeight,
    this.averageEv,
    this.anchorLuminance = 0.18,
    this.isAnalyzing = false,
  });

  bool get needsImageStream => multiSpotEnabled;

  bool get hasPins => pins.isNotEmpty;

  AdvancedSpotMeteringState copyWith({
    bool? zoneOverlayEnabled,
    bool? multiSpotEnabled,
    List<MeteringPin>? pins,
    List<int>? zoneColorGrid,
    bool clearZoneGrid = false,
    double? averageEv,
    bool clearAverageEv = false,
    double? anchorLuminance,
    bool? isAnalyzing,
  }) {
    return AdvancedSpotMeteringState(
      zoneOverlayEnabled: zoneOverlayEnabled ?? this.zoneOverlayEnabled,
      multiSpotEnabled: multiSpotEnabled ?? this.multiSpotEnabled,
      pins: pins ?? this.pins,
      zoneColorGrid: clearZoneGrid ? null : (zoneColorGrid ?? this.zoneColorGrid),
      zoneGridWidth: zoneGridWidth,
      zoneGridHeight: zoneGridHeight,
      averageEv: clearAverageEv ? null : (averageEv ?? this.averageEv),
      anchorLuminance: anchorLuminance ?? this.anchorLuminance,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
    );
  }
}

class AdvancedSpotMeteringNotifier extends Notifier<AdvancedSpotMeteringState> {
  int _pinCounter = 0;
  bool _analysisInFlight = false;
  DateTime? _lastAnalysisAt;
  static const _minAnalysisInterval = Duration(milliseconds: 120);

  @override
  AdvancedSpotMeteringState build() => const AdvancedSpotMeteringState();

  void toggleZoneOverlay() {
    final next = !state.zoneOverlayEnabled;
    state = state.copyWith(
      zoneOverlayEnabled: next,
      clearZoneGrid: !next,
    );
  }

  void toggleMultiSpot() {
    final next = !state.multiSpotEnabled;
    state = state.copyWith(
      multiSpotEnabled: next,
      pins: next ? state.pins : const [],
      clearAverageEv: !next,
    );
  }

  void addPin(double normalizedX, double normalizedY) {
    if (!state.multiSpotEnabled) return;
    if (state.pins.length >= AdvancedSpotMeteringEngine.maxPins) return;

    _pinCounter++;
    final pin = MeteringPin(
      id: 'pin_$_pinCounter',
      normalizedX: normalizedX.clamp(0, 1),
      normalizedY: normalizedY.clamp(0, 1),
    );
    state = state.copyWith(pins: [...state.pins, pin]);
  }

  void movePin(String id, double normalizedX, double normalizedY) {
    state = state.copyWith(
      pins: state.pins
          .map((p) => p.id == id
              ? p.copyWith(
                  normalizedX: normalizedX.clamp(0, 1),
                  normalizedY: normalizedY.clamp(0, 1),
                  clearEv: true,
                )
              : p)
          .toList(),
    );
  }

  void removePin(String id) {
    final next = state.pins.where((p) => p.id != id).toList();
    state = state.copyWith(
      pins: next,
      clearAverageEv: next.isEmpty,
    );
  }

  void clearPins() {
    state = state.copyWith(
      pins: const [],
      clearAverageEv: true,
    );
  }

  /// Process a camera frame — throttled, runs analysis on a background isolate.
  Future<void> onCameraFrame(
    CameraImage image, {
    required double evTarget,
    required double evAnchor,
    bool buildZoneGrid = false,
  }) async {
    if (!state.needsImageStream) return;
    if (_analysisInFlight) return;

    final now = DateTime.now();
    if (_lastAnalysisAt != null &&
        now.difference(_lastAnalysisAt!) < _minAnalysisInterval) {
      return;
    }

    _analysisInFlight = true;
    _lastAnalysisAt = now;
    state = state.copyWith(isAnalyzing: true);

    try {
      final result = await analyzeFrame(
        image: image,
        evTarget: evTarget,
        evAnchor: evAnchor,
        anchorLuminance: state.anchorLuminance,
        pins: state.pins
            .map((p) => (id: p.id, nx: p.normalizedX, ny: p.normalizedY))
            .toList(),
        buildZoneGrid: buildZoneGrid,
      );

      var nextPins = state.pins;
      if (result.pinEvs.isNotEmpty) {
        final evMap = {for (final e in result.pinEvs) e.id: e.ev};
        nextPins = state.pins
            .map((p) => evMap.containsKey(p.id) ? p.copyWith(ev: evMap[p.id]) : p)
            .toList();
      }

      final avg = nextPins.isNotEmpty
          ? AdvancedSpotMeteringEngine.averageEv(
              nextPins.map((p) => p.ev ?? evAnchor),
            )
          : null;

      state = state.copyWith(
        zoneColorGrid: buildZoneGrid ? result.zoneColors : state.zoneColorGrid,
        pins: nextPins,
        averageEv: avg,
        anchorLuminance: result.centerLuminance > 0
            ? result.centerLuminance
            : state.anchorLuminance,
        isAnalyzing: false,
      );
    } catch (e) {
      debugPrint('[AdvancedSpotMetering] frame analysis error: $e');
      state = state.copyWith(isAnalyzing: false);
    } finally {
      _analysisInFlight = false;
    }
  }

  /// Recommended exposure from multi-spot average EV.
  ({double aperture, double shutter, double iso})? recommendedExposure({
    required double filmIso,
    double? preferredAperture,
  }) {
    final ev = state.averageEv;
    if (ev == null || !state.hasPins) return null;

    final evAtFilmIso = ev + _log2(filmIso / 100);
    final aperture = preferredAperture ?? 2.8;
    final rawShutter = math.pow(aperture, 2) / math.pow(2, evAtFilmIso);
    return (
      aperture: SensorService.snapAperture(aperture),
      shutter: SensorService.snapShutterSpeed(rawShutter.toDouble()),
      iso: filmIso,
    );
  }

  static double _log2(double x) => math.log(x) / math.ln2;
}

final advancedSpotMeteringProvider =
    NotifierProvider<AdvancedSpotMeteringNotifier, AdvancedSpotMeteringState>(
  AdvancedSpotMeteringNotifier.new,
);
