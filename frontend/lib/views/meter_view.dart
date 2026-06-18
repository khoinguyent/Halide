import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../config/app_config.dart';
import '../core/models/notification_model.dart';
import '../core/providers/notification_provider.dart';
import '../features/meter/providers/meter_provider.dart';
import '../features/meter/providers/advanced_spot_metering_provider.dart';
import '../features/meter/presentation/widgets/advanced_spot_metering_overlay.dart';
import '../features/meter/presentation/widgets/zone_overlay_painter.dart';
import '../models/roll.dart';
import '../models/roll_status.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/roll_provider.dart';
import '../providers/ui_state_provider.dart';
import '../services/guidance_service.dart';
import '../services/meter_debug_log.dart';
import '../widgets/debug_log_sheet.dart';
import '../widgets/guidance/lab_drive_sync_guidance.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/glass_panel.dart';
import '../services/sensor_service.dart';
import '../widgets/aperture_slider_control.dart';

class MeterView extends ConsumerStatefulWidget {
  const MeterView({Key? key}) : super(key: key);

  @override
  ConsumerState<MeterView> createState() => _MeterViewState();
}
class _MeterViewState extends ConsumerState<MeterView> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  /// True while [CameraController.dispose] is running — blocks starting a new camera until done.
  /// Without this, switching away from the meter tab nulled [_controller] before dispose finished,
  /// so [_checkCameraVisibility] could start a second [_setupCamera] and leave the UI stuck loading.
  bool _disposingCamera = false;
  /// Prevents overlapping [_setupCamera] calls from rapid tab / lifecycle notifications.
  bool _setupInProgress = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  Timer? _metadataTimer;

  final GlobalKey _meterSpotKey = GlobalKey();
  final GlobalKey _meterLogToRollKey = GlobalKey();
  bool _meterIntroScheduled = false;
  bool _exposureHudExpanded = true;

  /// Reserve space above the bottom tab bar for the exposure HUD + optional zone legend below it.
  static const double _navBarClearance = 40;
  static const double _collapsedHudHeight = 64;
  static const double _expandedHudHeight = 248;
  static const double _spotRingSize = 52;
  static const double _zoneLegendHeight = ZoneLegendHud.preferredHeight;
  static const double _legendBelowHudGap = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial setup if we are on the correct tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCameraVisibility();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _lifecycleState = state;
    });
    _checkCameraVisibility();
  }

  /// While the **system camera permission sheet** (or similar) is up, iOS often reports
  /// [AppLifecycleState.inactive], not [AppLifecycleState.resumed]. Treating only `resumed` as
  /// foreground used to set `shouldRun == false`, dispose the camera mid-`initialize()`, and leave
  /// the meter stuck on "Starting camera…" after the user tapped Allow.
  bool _lifecycleAllowsCamera() {
    switch (_lifecycleState) {
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        return true;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        return false;
    }
  }

  void _checkCameraVisibility() {
    if (!mounted) return;

    // Prefer live shell index (authoritative). [homeTabIndexProvider] is kept in sync from
    // [_ShellArchiveRefresh] but can lag a frame; shell.maybeOf is null in some subtree cases.
    final shell = StatefulNavigationShell.maybeOf(context);
    final isTabActive = shell != null
        ? shell.currentIndex == 2
        : ref.read(homeTabIndexProvider) == 2;

    final shouldRun = isTabActive && _lifecycleAllowsCamera();

    if (shouldRun &&
        !_isCameraInitialized &&
        _controller == null &&
        !_disposingCamera &&
        !_setupInProgress) {
      debugPrint('[MeterView] Starting camera (tab active, lifecycle=$_lifecycleState)');
      _setupCamera();
    } else if (!shouldRun && (_controller != null || _setupInProgress)) {
      debugPrint('[MeterView] Stopping camera (tab=$isTabActive lifecycle=$_lifecycleState)');
      unawaited(_disposeCamera());
    }
  }

  Future<void> _disposeCamera() async {
    _metadataTimer?.cancel();
    _metadataTimer = null;
    final controller = _controller;
    if (controller == null && !_setupInProgress) return;

    _disposingCamera = true;
    _controller = null;
    if (mounted) setState(() => _isCameraInitialized = false);

    if (controller != null) {
      try {
        if (controller.value.isInitialized) {
          await controller.pausePreview();
        }
      } catch (_) {}
      try {
        await controller.dispose();
      } catch (e) {
        debugPrint('[MeterView] dispose camera: $e');
      }
    }

    _disposingCamera = false;
    _setupInProgress = false;
    if (mounted) _checkCameraVisibility();
  }

  static const _metadataChannel = MethodChannel('com.halide/camera_metadata');

  Future<void> _setupCamera() async {
    if (_disposingCamera || _setupInProgress) return;
    _setupInProgress = true;

    final cameras = await availableCameras();
    if (!mounted) {
      _setupInProgress = false;
      return;
    }
    if (cameras.isEmpty) {
      _setupInProgress = false;
      return;
    }
    if (_disposingCamera) {
      _setupInProgress = false;
      return;
    }

    final c = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );
    _controller = c;

    try {
      await c.initialize();
      // [inactive] during permission / disposed mid-flight — do not finish or setState.
      if (!mounted || _controller != c) return;

      // Bind iOS native metadata to the **same** AVCaptureDevice as the Flutter preview.
      // Without this, DiscoverySession returns a different device → ISO/shutter often 0 → EV 0 → wrong 8s.
      try {
        await _metadataChannel.invokeMethod('setActiveCaptureDevice', {
          'deviceId': c.description.name,
        });
        MeterDebugLog.log('setActiveCaptureDevice: ${c.description.name}');
      } catch (e) {
        MeterDebugLog.log('setActiveCaptureDevice failed: $e');
      }

      // Center-weighted metering: pin AE point to the frame center.
      try {
        await _metadataChannel.invokeMethod('setupMeteringPoint');
      } catch (e) {
        MeterDebugLog.log('setupMeteringPoint: $e');
      }
      try {
        await c.setExposureMode(ExposureMode.auto);
        await c.setExposurePoint(const Offset(0.5, 0.5));
      } catch (_) {}

      // iOS: first launch after granting permission sometimes leaves preview paused until resumed.
      try {
        await c.resumePreview();
      } catch (_) {}

      if (!mounted || _controller != c) return;
      setState(() => _isCameraInitialized = true);

      // Wait for CameraPreview to mount, then resume again — avoids black preview + stuck "Starting camera…"
      // when the meter intro coach runs on first open.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _resumeCameraPreviewIfNeeded();
        _scheduleMeterIntroIfNeeded();
      });

      // Poll hardware AE metadata via a timer rather than inside the image
      // stream callback.  Image-stream callbacks run on a background thread;
      // platform-channel calls from there are unreliable on iOS and cause
      // silent failures.  A 500 ms timer runs on the main isolate and is
      // entirely independent of the preview stream.
      _startMetadataPolling();
    } catch (e) {
      debugPrint('[MeterView] Camera initialization error: $e');
      if (_controller == c) {
        _controller = null;
        try {
          await c.dispose();
        } catch (_) {}
        if (mounted) setState(() => _isCameraInitialized = false);
      }
    } finally {
      _setupInProgress = false;
      if (mounted &&
          _controller == null &&
          !_isCameraInitialized &&
          !_disposingCamera) {
        _checkCameraVisibility();
      }
    }
  }


  void _startMetadataPolling() {
    _metadataTimer?.cancel();
    _metadataTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted) return;
      if (ref.read(meterProvider).isLocked) return;
      try {
        final Map<dynamic, dynamic> metadata =
            await _metadataChannel.invokeMethod('getMetadata');
        if (!mounted) return;
        ref.read(meterProvider.notifier).updateFromHardware(
          iso: (metadata['iso'] as num).toDouble(),
          shutter: (metadata['shutterSpeed'] as num).toDouble(),
          aperture: (metadata['aperture'] as num).toDouble(),
          isAdjusting: metadata['isAdjusting'] as bool? ?? false,
          targetOffset: (metadata['targetOffset'] as num?)?.toDouble() ?? 0.0,
          nativeDeviceId: metadata['deviceUniqueId'] as String?,
        );
      } catch (e) {
        MeterDebugLog.log('metadata poll error: $e');
        debugPrint('[MeterView] metadata poll: $e');
      }
    });
  }

  Future<void> _revertToCenterMetering() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await _metadataChannel.invokeMethod('setupMeteringPoint');
    } catch (e) {
      MeterDebugLog.log('setupMeteringPoint (revert): $e');
    }
    try {
      await c.setExposurePoint(const Offset(0.5, 0.5));
    } catch (_) {}
  }

  void _handleLockToggle() {
    HapticFeedback.mediumImpact();
    ref.read(meterProvider.notifier).toggleLock();
  }

  void _scheduleMeterIntroIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_meterIntroScheduled) return;
      // Lock synchronously before any await — otherwise two callbacks can both pass the guard.
      _meterIntroScheduled = true;

      final plan = ref.read(userPlanProvider);
      if (!plan.isPro) {
        _meterIntroScheduled = false;
        return;
      }
      if (await GuidanceService.instance.hasSeenMeterIntro) {
        _meterIntroScheduled = false;
        return;
      }

      await _resumeCameraPreviewIfNeeded();
      if (!mounted) return;
      // Extra beat so the preview texture is visible before coach overlays (they can pause iOS preview).
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      _showMeterIntroStep1();
    });
  }

  /// Coach overlays can pause the camera preview on iOS; resume after each step.
  Future<void> _resumeCameraPreviewIfNeeded() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.resumePreview();
    } catch (e) {
      debugPrint('[MeterView] resumePreview: $e');
    }
    if (mounted) setState(() {});
  }

  void _showMeterIntroStep1() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _resumeCameraPreviewIfNeeded();
      if (!mounted) return;
      final coach = buildSingleStepArchiveGuidance(
        targetKey: _meterSpotKey,
        identify: 'meter_spot_intro',
        contentAlign: ContentAlign.bottom,
        body:
            'Tap the circle to spot-meter the center and return to aperture priority. '
            'Tap f/ or SS to set exposure, EV or ISO for compensation, then LOCK to hold exposure while you compose.',
        onCompleted: () {
          unawaited(_resumeCameraPreviewIfNeeded());
          Future<void>.delayed(const Duration(milliseconds: 200), () {
            if (mounted) _showMeterIntroStep2();
          });
        },
      );
      coach.show(context: context);
    });
  }

  void _showMeterIntroStep2() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _resumeCameraPreviewIfNeeded();
      if (!mounted) return;
      final coach = buildSingleStepArchiveGuidance(
        targetKey: _meterLogToRollKey,
        identify: 'meter_log_to_roll_intro',
        contentAlign: ContentAlign.top,
        paddingFocus: 6,
        body:
            'Tap LOG TO ROLL to save aperture, shutter, and meter details to a roll in Shooting. '
            'Entries show in Shot Log with your archive EXIF logs.',
        onCompleted: () {
          unawaited(GuidanceService.instance.setMeterIntroSeen());
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _resumeCameraPreviewIfNeeded();
            if (mounted) _checkCameraVisibility();
          });
        },
      );
      coach.show(context: context);
    });
  }

  /// Staging / debug: long-press **PRECISION METER** title — meter channel only (same data as before).
  void _showMeterDebugSheet() {
    showHalideDebugLogSheet(
      context,
      title: 'METER DEBUG LOG',
      channelFilter: 'Meter',
      emptyHint: '(no samples yet — wait ~1s on meter tab)',
    );
  }

  Future<void> _showIsoPicker() async {
    final current = ref.read(meterProvider);
    final isoStops = <double>[25, 50, 100, 200, 400, 800, 1600, 3200, 6400];
    double selected = current.iso;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text('ISO',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: isoStops.map((v) {
                  final isSelected = v == selected;
                  return InkWell(
                    onTap: () {
                      setSheet(() => selected = v);
                      ref.read(meterProvider.notifier).updateISO(v);
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: _pickerChip(v.toStringAsFixed(0), isSelected),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Changes will update EV and the computed exposure.',
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEvPicker() async {
    final current = ref.read(meterProvider);
    double comp = current.evComp;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'EV',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Compensation: ${comp >= 0 ? '+' : ''}${comp.toStringAsFixed(1)}',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Slider(
                    value: comp,
                    min: -5,
                    max: 5,
                    divisions: 100,
                    activeColor: const Color(0xFFF97316),
                    inactiveColor: Colors.white12,
                    onChanged: (v) {
                      setModalState(() => comp = v);
                      ref.read(meterProvider.notifier).updateEVComp(v);
                    },
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton(
                    onPressed: () {
                      setModalState(() => comp = 0);
                      ref.read(meterProvider.notifier).updateEVComp(0);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.8),
                      side: BorderSide(color: Colors.white.withOpacity(0.12)),
                      backgroundColor: Colors.white10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('RESET'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAperturePicker() async {
    final current = ref.read(meterProvider);
    final stops = SensorService.standardApertures;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        side: BorderSide(color: Colors.white10, width: 0.5),
      ),
      builder: (ctx) {
        final bottomPadding = MediaQuery.of(ctx).padding.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'APERTURE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Drag to set f-stop. Tap the meter circle to return to aperture priority.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              ApertureSliderControl(
                apertures: stops,
                value: current.aperture,
                onChanged: (v) {
                  ref.read(meterProvider.notifier).updateAperture(v);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showShutterPicker() async {
    final current = ref.read(meterProvider);
    // seconds; includes common 1/x speeds and a few long exposures
    final speeds = <double>[
      1 / 4000,
      1 / 2000,
      1 / 1000,
      1 / 500,
      1 / 250,
      1 / 125,
      1 / 60,
      1 / 30,
      1 / 15,
      1 / 8,
      1 / 4,
      1 / 2,
      1,
      2,
      4,
      8,
      15,
      30,
    ];
    double selected = current.shutterSpeed;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text('SHUTTER SPEED',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
              const SizedBox(height: 8),
              Text(
                'Selecting a shutter speed switches to Shutter Priority.\nTap the meter circle to return to Aperture Priority.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: speeds.map((v) {
                  final isSelected = (v - selected).abs() < 1e-9;
                  return InkWell(
                    onTap: () {
                      setSheet(() => selected = v);
                      ref.read(meterProvider.notifier).updateShutterSpeed(v);
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: _pickerChip(_formatShutterSpeed(v), isSelected),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkCameraVisibility();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when the selected tab changes, and re-run visibility (shell sync / go() paths).
    ref.watch(homeTabIndexProvider);
    ref.listen<int>(homeTabIndexProvider, (previous, next) {
      _checkCameraVisibility();
    });

    final meterState = ref.watch(meterProvider);
    final plan = ref.watch(userPlanProvider);
    final isPro = plan.isPro;
    final spotState = ref.watch(advancedSpotMeteringProvider);

    ref.listen<AdvancedSpotMeteringState>(advancedSpotMeteringProvider, (prev, next) {
      if (next.multiSpotEnabled && prev?.multiSpotEnabled != true && _exposureHudExpanded) {
        setState(() => _exposureHudExpanded = false);
      }
    });

    final zoneLegendReserve = spotState.zoneOverlayEnabled
        ? _zoneLegendHeight + _legendBelowHudGap
        : 0.0;
    final exposurePanelBottom = _navBarClearance + zoneLegendReserve;
    final evTarget = meterState.isLocked ? meterState.ev : meterState.evBase;

    final showMeterDebug = AppConfig.showInAppDiagnostics;

    return HalideScaffold(
      appBar: AppBar(
        title: showMeterDebug
            ? GestureDetector(
                onLongPress: _showMeterDebugSheet,
                child: const Text(
                  'PRECISION METER',
                  style: TextStyle(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w300,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              )
            : const Text(
                'PRECISION METER',
                style: TextStyle(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w300,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camera / loading — always fill; non-positioned Center left the stack with ~no height on some layouts.
          Positioned.fill(
            child: _isCameraInitialized && _controller != null
                ? ColoredBox(
                    color: Colors.black,
                    child: _MeterFullBleedPreview(controller: _controller!),
                  )
                : Container(
                    color: const Color(0xFF141414),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
                        const SizedBox(height: 16),
                        Text(
                          'Starting camera…',
                          style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
          ),

          if (!isPro)
            _MeterFreeOverlay(onUpgrade: () => context.push('/paywall'))
          else ...[
            // Advanced Spot Metering (Zone overlay + Multi-spot pins)
            if (_isCameraInitialized && _controller != null)
              AdvancedSpotMeteringOverlay(
                controller: _controller!,
                formatShutter: _formatShutterSpeed,
                onRevertToCenterMetering: _revertToCenterMetering,
              ),

            // Center spot ring — de-emphasized while multi-spot pins drive exposure.
            if (!spotState.multiSpotEnabled || !spotState.hasPins)
              Align(
                alignment: const Alignment(0, -0.38),
                child: GestureDetector(
                  key: _meterSpotKey,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(meterProvider.notifier).resetToAperturePriority();
                  },
                  child: Container(
                    width: _spotRingSize,
                    height: _spotRingSize,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: meterState.isLocked
                            ? Colors.orangeAccent
                            : meterState.lastChanged == ExposureControl.shutter
                                ? Colors.blueAccent.withOpacity(0.8)
                                : Colors.white54,
                        width: 1.2,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
              ),

            // Zone legend — below exposure panel, just above the bottom tab bar.
            if (spotState.zoneOverlayEnabled)
              Positioned(
                left: 0,
                right: 0,
                bottom: _navBarClearance,
                child: ZoneLegendHud(dockBelowExposurePanel: true),
              ),

            // Exposure HUD — collapsible so multi-spot pins can be placed underneath.
            Positioned(
              bottom: exposurePanelBottom,
              left: 20,
              right: 20,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                child: GlassPanel(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: _exposureHudExpanded ? 8 : 12,
                      horizontal: 20,
                    ),
                    child: _exposureHudExpanded
                        ? _buildExpandedExposureHud(meterState, spotState)
                        : _buildCollapsedExposureHud(meterState, spotState),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleExposureHud({bool? expanded}) {
    HapticFeedback.selectionClick();
    setState(() => _exposureHudExpanded = expanded ?? !_exposureHudExpanded);
  }

  Widget _hudExpandCollapseButton({required bool expanded}) {
    return IconButton(
      onPressed: () => _toggleExposureHud(expanded: !expanded),
      icon: Icon(
        expanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
        color: Colors.white70,
      ),
      tooltip: expanded ? 'Collapse exposure panel' : 'Expand exposure panel',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  Widget _hudCollapseHandle() {
    return GestureDetector(
      onTap: () => _toggleExposureHud(expanded: false),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  _ExposurePanelReading _exposurePanelReading(
    MeterState meterState,
    AdvancedSpotMeteringState spotState,
  ) {
    if (spotState.multiSpotEnabled && spotState.hasPins) {
      final avg = spotState.averageEv;
      if (avg != null) {
        final evAtFilmIso = avg +
            _log2(meterState.iso / 100) +
            meterState.evComp;
        final rawShutter = math.pow(meterState.aperture, 2) / math.pow(2, evAtFilmIso);
        return _ExposurePanelReading(
          ev: avg + meterState.evComp,
          shutterSpeed: SensorService.snapShutterSpeed(rawShutter.toDouble()),
          fromMultiSpot: true,
          pinCount: spotState.pins.length,
        );
      }
    }

    return _ExposurePanelReading(
      ev: meterState.ev,
      shutterSpeed: meterState.shutterSpeed,
      fromMultiSpot: spotState.multiSpotEnabled,
      pinCount: spotState.pins.length,
    );
  }

  static double _log2(double x) => math.log(x) / math.ln2;

  Widget _buildCollapsedExposureHud(
    MeterState meterState,
    AdvancedSpotMeteringState spotState,
  ) {
    final reading = _exposurePanelReading(meterState, spotState);
    final accent = reading.usesPinAverage
        ? const Color(0xFFF97316)
        : meterState.isLocked
            ? Colors.orangeAccent
            : meterState.isAeStable
                ? const Color(0xFF4ADE80)
                : Colors.white24;

    return SizedBox(
      height: _collapsedHudHeight - 24,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _toggleExposureHud(expanded: true),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  _collapsedMetric('f/${meterState.aperture.toStringAsFixed(1)}'),
                  const SizedBox(width: 14),
                  _collapsedMetric(_formatShutterSpeed(reading.shutterSpeed)),
                  const SizedBox(width: 14),
                  _collapsedMetric('EV ${reading.ev.toStringAsFixed(1)}'),
                  if (reading.usesPinAverage) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${reading.pinCount} pin${reading.pinCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                  ),
                ],
              ),
            ),
          ),
          _hudExpandCollapseButton(expanded: false),
        ],
      ),
    );
  }

  Widget _collapsedMetric(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildExpandedExposureHud(
    MeterState meterState,
    AdvancedSpotMeteringState spotState,
  ) {
    final reading = _exposurePanelReading(meterState, spotState);
    final multiSpotAccent = const Color(0xFFF97316);
    final statusColor = reading.usesPinAverage
        ? multiSpotAccent
        : meterState.isLocked
            ? Colors.orangeAccent
            : meterState.isAeStable
                ? const Color(0xFF4ADE80)
                : Colors.white38;
    final statusLabel = reading.usesPinAverage
        ? 'MULTI-SPOT · ${reading.pinCount} PIN${reading.pinCount == 1 ? '' : 'S'}'
        : spotState.multiSpotEnabled
            ? 'MULTI-SPOT — TAP TO ADD PINS'
            : meterState.isLocked
                ? 'LOCKED'
                : meterState.isAeStable
                    ? 'STABLE'
                    : 'METERING…';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: 36),
            Expanded(child: Center(child: _hudCollapseHandle())),
            _hudExpandCollapseButton(expanded: true),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (reading.usesPinAverage)
              _infoColumn(
                'PINS',
                '${reading.pinCount}',
                valueColor: multiSpotAccent,
              )
            else
              _infoColumn('LUX', '~${meterState.lux.toStringAsFixed(0)}'),
            _infoColumn('EV', reading.ev.toStringAsFixed(1), onTap: _showEvPicker),
            _infoColumn('ISO', meterState.iso.toStringAsFixed(0), onTap: _showIsoPicker),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
            ),
            const SizedBox(width: 4),
            Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 8,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _valueColumn('f/', meterState.aperture.toStringAsFixed(1), onTap: _showAperturePicker),
            _valueColumn(
              'SS',
              _formatShutterSpeed(reading.shutterSpeed),
              onTap: _showShutterPicker,
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 40,
          child: ElevatedButton(
            onPressed: _handleLockToggle,
            style: ElevatedButton.styleFrom(
              backgroundColor: meterState.isLocked ? Colors.orangeAccent : Colors.white10,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              meterState.isLocked ? 'UNLOCK' : 'LOCK EXPOSURE',
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              key: _meterLogToRollKey,
              onPressed: _showLogReadingToRollSheet,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'LOG TO ROLL →',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
            IconButton(
              onPressed: _showLogReadingToRollSheet,
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Icon(Icons.camera_rounded, color: Colors.orange, size: 20),
              ),
              tooltip: 'Log meter reading to roll',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pickerChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF97316).withOpacity(0.18) : Colors.white10,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isSelected ? const Color(0xFFF97316) : Colors.white.withOpacity(0.10),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: const Color(0xFFF97316).withOpacity(0.30), spreadRadius: 2, blurRadius: 15)]
            : const [],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.75),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _infoColumn(String label, String value, {VoidCallback? onTap, Color? valueColor}) {
    final child = Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1)),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: child,
      ),
    );
  }

  Widget _valueColumn(String prefix, String value, {VoidCallback? onTap}) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(prefix, style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w200)),
      ],
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: row,
      ),
    );
  }

  String _formatShutterSpeed(double ss) {
    if (ss >= 1) {
      return ss == ss.roundToDouble()
          ? '${ss.round()}s'
          : '${ss.toStringAsFixed(1)}s';
    }
    return '1/${(1 / ss).round()}';
  }

  String _buildMeterExifNotes(MeterState s) {
    final mode =
        s.lastChanged == ExposureControl.shutter ? 'Shutter priority' : 'Aperture priority';
    final lock = s.isLocked ? ' | LOCKED' : '';
    return 'Light meter | EV ${s.ev.toStringAsFixed(1)} | '
        'Lux ~${s.lux.toStringAsFixed(0)} | Film ISO ${s.iso.toStringAsFixed(0)} | '
        'f/${s.aperture.toStringAsFixed(1)} | ${_formatShutterSpeed(s.shutterSpeed)} | '
        '$mode$lock';
  }

  Future<void> _logMeterToRoll(BuildContext sheetContext, String rollId) async {
    Navigator.of(sheetContext).pop();
    final meter = ref.read(meterProvider);
    final shutter = _formatShutterSpeed(meter.shutterSpeed);
    final notes = _buildMeterExifNotes(meter);

    double? lat;
    double? lng;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final p = await Geolocator.getCurrentPosition();
          lat = p.latitude;
          lng = p.longitude;
        }
      }
    } catch (_) {}

    final user = ref.read(userProvider);
    if (user == null) return;
    final token = await user.getIdToken();
    if (token == null) return;

    try {
      await ref.read(rollServiceProvider).logShot(
            token,
            rollId,
            aperture: meter.aperture,
            shutterSpeed: shutter,
            lat: lat,
            lng: lng,
            notes: notes,
          );
      ref.invalidate(dashboardRollsProvider);
      ref.invalidate(rollDetailProvider(rollId));
      if (mounted) {
        ref.read(notificationProvider.notifier).show(
              'METER READING LOGGED',
              type: NotificationType.success,
            );
      }
    } catch (e) {
      debugPrint('[MeterView] log to roll failed: $e');
      if (mounted) {
        ref.read(notificationProvider.notifier).show(
              'COULDN\'T LOG READING. TRY AGAIN.',
              type: NotificationType.error,
            );
      }
    }
  }

  Future<void> _showLogReadingToRollSheet() async {
    HapticFeedback.lightImpact();
    ref.invalidate(dashboardRollsProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final asyncRolls = ref.watch(dashboardRollsProvider);
        final maxH = MediaQuery.of(ctx).size.height * 0.52;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.of(ctx).padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'LOG METER READING',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick a roll in Shooting status. Saves aperture, shutter, and meter details to the shot log.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: maxH,
                  child: asyncRolls.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Text(
                        'Could not load rolls.',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    ),
                    data: (rolls) {
                      final shooting =
                          rolls.where((r) => r.status == RollStatus.shooting).toList();
                      if (shooting.isEmpty) {
                        return Center(
                          child: Text(
                            'No rolls in Shooting status.\nStart a roll from the archive.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withOpacity(0.5), height: 1.4),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: shooting.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final roll = shooting[index];
                          return _MeterShootingRollTile(
                            roll: roll,
                            onTap: () => _logMeterToRoll(ctx, roll.id),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MeterShootingRollTile extends StatelessWidget {
  final Roll roll;
  final VoidCallback onTap;

  const _MeterShootingRollTile({
    required this.roll,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (roll.title?.trim().isNotEmpty ?? false) ? roll.title!.trim() : 'Untitled roll';
    final film = '${roll.brand} ${roll.name}'.trim();
    final iso = roll.shotAtIso != null ? 'ISO ${roll.shotAtIso}' : 'ISO —';
    final cam = roll.cameraName?.trim().isNotEmpty == true ? roll.cameraName! : 'No camera';
    final lens = roll.lensName?.trim().isNotEmpty == true ? roll.lensName! : '—';
    final gearLine = '$cam · $lens';

    return Material(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                film,
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '$iso · $gearLine',
                style: TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Same aspect math as [CameraPreview]: portrait uses [1 / aspectRatio] so the preview
/// is not squeezed when we size the [FittedBox] child (raw sensor AR was stretching the image).
DeviceOrientation _meterApplicableOrientation(CameraController c) {
  final v = c.value;
  if (v.isRecordingVideo) {
    return v.recordingOrientation!;
  }
  return v.previewPauseOrientation ??
      v.lockedCaptureOrientation ??
      v.deviceOrientation;
}

bool _meterPreviewIsLandscape(CameraController c) {
  final o = _meterApplicableOrientation(c);
  return o == DeviceOrientation.landscapeLeft || o == DeviceOrientation.landscapeRight;
}

double _meterDisplayAspectRatio(CameraController c) {
  final ar = c.value.aspectRatio;
  if (ar <= 0 || !ar.isFinite) return 3 / 4;
  return _meterPreviewIsLandscape(c) ? ar : 1.0 / ar;
}

/// Edge-to-edge preview: [FittedBox] + [BoxFit.cover] crops like the system camera; sizing
/// matches [CameraPreview]'s internal portrait/landscape aspect ratio.
class _MeterFullBleedPreview extends StatelessWidget {
  final CameraController controller;

  const _MeterFullBleedPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final displayAr = _meterDisplayAspectRatio(controller);
        if (displayAr <= 0 || !displayAr.isFinite) {
          return Center(child: CameraPreview(controller));
        }
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxWidth / displayAr,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}

/// Blur + tint so the live preview stays visible but unclear; CTA opens paywall.
class _MeterFreeOverlay extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _MeterFreeOverlay({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(color: Colors.transparent),
            ),
            Container(color: Colors.black.withOpacity(0.4)),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: GlassPanel(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_person_rounded, size: 56, color: Colors.orangeAccent),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'PRO FEATURE',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Precision light metering is included with Halide Pro.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upgrade to unlock spot metering, EV compensation, manual exposure, and logging to your rolls.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 28),
                        FilledButton(
                          onPressed: onUpgrade,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            'VIEW PLANS',
                            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExposurePanelReading {
  final double ev;
  final double shutterSpeed;
  final bool fromMultiSpot;
  final int pinCount;

  const _ExposurePanelReading({
    required this.ev,
    required this.shutterSpeed,
    required this.fromMultiSpot,
    required this.pinCount,
  });

  bool get usesPinAverage => fromMultiSpot && pinCount > 0;
}
