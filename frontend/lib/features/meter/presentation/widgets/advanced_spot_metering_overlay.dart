import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/preview_coordinate_mapper.dart';
import '../../providers/advanced_spot_metering_provider.dart';
import '../../providers/meter_provider.dart';
import '../../services/zone_overlay_shader_service.dart';
import 'metering_pin_widget.dart';
import 'zone_overlay_painter.dart';
import 'zone_overlay_shader_layer.dart';

/// Self-contained Advanced Spot Metering overlay for the camera viewfinder.
///
/// System A: GPU fragment-shader zone overlay (BackdropFilter on live preview)
/// System B: Multi-spot average metering (tap / drag / double-tap pins)
class AdvancedSpotMeteringOverlay extends ConsumerStatefulWidget {
  final CameraController controller;
  final String Function(double) formatShutter;
  final Future<void> Function()? onRevertToCenterMetering;

  const AdvancedSpotMeteringOverlay({
    super.key,
    required this.controller,
    required this.formatShutter,
    this.onRevertToCenterMetering,
  });

  @override
  ConsumerState<AdvancedSpotMeteringOverlay> createState() =>
      _AdvancedSpotMeteringOverlayState();
}

class _AdvancedSpotMeteringOverlayState
    extends ConsumerState<AdvancedSpotMeteringOverlay> {
  bool _imageStreamActive = false;
  bool _cpuZoneFallback = false;
  bool _shaderLoadChecked = false;
  String? _draggingPinId;

  @override
  void initState() {
    super.initState();
    _initShaderAvailability();
  }

  Future<void> _initShaderAvailability() async {
    final ok = await ZoneOverlayShaderService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _shaderLoadChecked = true;
      _cpuZoneFallback = !ok;
    });
  }

  @override
  void dispose() {
    _stopImageStream();
    super.dispose();
  }

  bool _needsImageStream(AdvancedSpotMeteringState spot) {
    return spot.multiSpotEnabled ||
        (spot.zoneOverlayEnabled && _cpuZoneFallback);
  }

  Future<void> _ensureImageStream(bool needed) async {
    final c = widget.controller;
    if (!c.value.isInitialized) return;

    if (needed && !_imageStreamActive) {
      try {
        await c.startImageStream(_onImageStream);
        _imageStreamActive = true;
      } catch (e) {
        debugPrint('[AdvancedSpotMetering] startImageStream: $e');
      }
    } else if (!needed && _imageStreamActive) {
      await _stopImageStream();
    }
  }

  Future<void> _stopImageStream() async {
    if (!_imageStreamActive) return;
    final c = widget.controller;
    try {
      if (c.value.isInitialized && c.value.isStreamingImages) {
        await c.stopImageStream();
      }
    } catch (e) {
      debugPrint('[AdvancedSpotMetering] stopImageStream: $e');
    }
    _imageStreamActive = false;
  }

  void _onImageStream(CameraImage image) {
    final spot = ref.read(advancedSpotMeteringProvider);
    if (!_needsImageStream(spot)) return;

    final meter = ref.read(meterProvider);
    final evTarget = meter.isLocked ? meter.ev : meter.evBase;
    final evAnchor = meter.evBase;

    unawaited(
      ref.read(advancedSpotMeteringProvider.notifier).onCameraFrame(
            image,
            evTarget: evTarget,
            evAnchor: evAnchor,
            buildZoneGrid: spot.zoneOverlayEnabled && _cpuZoneFallback,
          ),
    );
  }

  void _handleTapDown(TapDownDetails details, Size viewSize) {
    final spot = ref.read(advancedSpotMeteringProvider);
    if (!spot.multiSpotEnabled) return;

    final layout = PreviewCoordinateMapper.layoutFromController(
      widget.controller,
      viewSize,
    );
    final sensor = PreviewCoordinateMapper.mapUiToSensor(
      uiTouchPoint: details.localPosition,
      uiViewSize: layout.uiViewSize,
      sensorImageSize: layout.sensorImageSize,
      orientation: layout.orientation,
    );

    HapticFeedback.lightImpact();
    ref.read(advancedSpotMeteringProvider.notifier).addPin(sensor.dx, sensor.dy);
  }

  void _handlePinDrag(String pinId, Offset uiPosition, Size viewSize) {
    final layout = PreviewCoordinateMapper.layoutFromController(
      widget.controller,
      viewSize,
    );
    final sensor = PreviewCoordinateMapper.mapUiToSensor(
      uiTouchPoint: uiPosition,
      uiViewSize: layout.uiViewSize,
      sensorImageSize: layout.sensorImageSize,
      orientation: layout.orientation,
    );
    ref.read(advancedSpotMeteringProvider.notifier).movePin(
          pinId,
          sensor.dx,
          sensor.dy,
        );
  }

  Future<void> _handleClearPins() async {
    HapticFeedback.mediumImpact();
    ref.read(advancedSpotMeteringProvider.notifier).clearPins();
    await widget.onRevertToCenterMetering?.call();
  }

  @override
  Widget build(BuildContext context) {
    final spotState = ref.watch(advancedSpotMeteringProvider);
    final meterState = ref.watch(meterProvider);
    final evTarget = meterState.isLocked ? meterState.ev : meterState.evBase;

    ref.listen(advancedSpotMeteringProvider, (prev, next) {
      if (prev?.zoneOverlayEnabled != next.zoneOverlayEnabled ||
          prev?.multiSpotEnabled != next.multiSpotEnabled) {
        final needed = _needsImageStream(next);
        _ensureImageStream(needed);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_shaderLoadChecked) {
        _ensureImageStream(_needsImageStream(spotState));
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        final layout = PreviewCoordinateMapper.layoutFromController(
          widget.controller,
          viewSize,
        );

        Widget? cpuFallback;
        if (spotState.zoneOverlayEnabled &&
            _cpuZoneFallback &&
            spotState.zoneColorGrid != null) {
          cpuFallback = CustomPaint(
            painter: ZoneOverlayPainter(
              colorGrid: spotState.zoneColorGrid!,
              gridWidth: spotState.zoneGridWidth,
              gridHeight: spotState.zoneGridHeight,
            ),
            size: viewSize,
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // System A: GPU zone overlay (samples camera via BackdropFilter)
            if (spotState.zoneOverlayEnabled && _shaderLoadChecked)
              IgnorePointer(
                child: ZoneOverlayShaderLayer(
                  evTarget: evTarget,
                  evAnchor: meterState.evBase,
                  anchorLuminance: spotState.anchorLuminance,
                  cpuFallback: cpuFallback != null
                      ? IgnorePointer(child: cpuFallback)
                      : null,
                ),
              )
            else if (cpuFallback != null)
              IgnorePointer(child: cpuFallback),

            if (spotState.multiSpotEnabled)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (d) => _handleTapDown(d, viewSize),
                ),
              ),

            for (final pin in spotState.pins)
              _buildPin(pin, layout, viewSize),

            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 12,
              right: 12,
              child: _SpotMeteringHudBar(
                zoneEnabled: spotState.zoneOverlayEnabled,
                multiSpotEnabled: spotState.multiSpotEnabled,
                pinCount: spotState.pins.length,
                onToggleZone: () {
                  HapticFeedback.selectionClick();
                  ref.read(advancedSpotMeteringProvider.notifier).toggleZoneOverlay();
                },
                onToggleMultiSpot: () {
                  HapticFeedback.selectionClick();
                  ref.read(advancedSpotMeteringProvider.notifier).toggleMultiSpot();
                },
                onClearPins: spotState.hasPins ? _handleClearPins : null,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPin(
    MeteringPin pin,
    ({InputAnalysisOrientation orientation, Size sensorImageSize, Size uiViewSize}) layout,
    Size viewSize,
  ) {
    final uiPos = PreviewCoordinateMapper.mapSensorToUi(
      sensorNormalized: Offset(pin.normalizedX, pin.normalizedY),
      uiViewSize: layout.uiViewSize,
      sensorImageSize: layout.sensorImageSize,
      orientation: layout.orientation,
    );

    return Positioned(
      left: uiPos.dx - MeteringPinWidget.pinDiameter / 2,
      top: uiPos.dy - MeteringPinWidget.pinDiameter / 2 - 22,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        onPanStart: (_) => setState(() => _draggingPinId = pin.id),
        onPanUpdate: (d) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(d.globalPosition);
          _handlePinDrag(pin.id, local, viewSize);
        },
        onPanEnd: (_) => setState(() => _draggingPinId = null),
        child: MeteringPinWidget(
          ev: pin.ev ?? ref.read(meterProvider).evBase,
          isDragging: _draggingPinId == pin.id,
          onDoubleTap: () {
            ref.read(advancedSpotMeteringProvider.notifier).removePin(pin.id);
          },
        ),
      ),
    );
  }
}

class _SpotMeteringHudBar extends StatelessWidget {
  final bool zoneEnabled;
  final bool multiSpotEnabled;
  final int pinCount;
  final VoidCallback onToggleZone;
  final VoidCallback onToggleMultiSpot;
  final Future<void> Function()? onClearPins;

  const _SpotMeteringHudBar({
    required this.zoneEnabled,
    required this.multiSpotEnabled,
    required this.pinCount,
    required this.onToggleZone,
    required this.onToggleMultiSpot,
    this.onClearPins,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        _HudToggleChip(
          label: l10n.zoneOverlay,
          isOn: zoneEnabled,
          onTap: onToggleZone,
        ),
        const SizedBox(width: 8),
        _HudToggleChip(
          label: l10n.multiSpot,
          isOn: multiSpotEnabled,
          onTap: onToggleMultiSpot,
        ),
        const Spacer(),
        if (onClearPins != null)
          TextButton(
            onPressed: () => onClearPins!(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF97316),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l10n.clearPinsCount(pinCount),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _HudToggleChip extends StatelessWidget {
  final String label;
  final bool isOn;
  final VoidCallback onTap;

  const _HudToggleChip({
    required this.label,
    required this.isOn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isOn
          ? const Color(0xFFF97316).withValues(alpha: 0.25)
          : Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOn
                  ? const Color(0xFFF97316)
                  : Colors.white.withValues(alpha: 0.2),
              width: isOn ? 1.5 : 1,
            ),
          ),
          child: Text(
            '$label: ${isOn ? context.l10n.toggleOn : context.l10n.toggleOff}',
            style: TextStyle(
              color: isOn ? Colors.white : Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
