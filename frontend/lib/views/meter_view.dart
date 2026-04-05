import 'dart:async' show Timer, unawaited;
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

class MeterView extends ConsumerStatefulWidget {
  const MeterView({Key? key}) : super(key: key);

  @override
  ConsumerState<MeterView> createState() => _MeterViewState();
}
class _MeterViewState extends ConsumerState<MeterView> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  Timer? _metadataTimer;

  final GlobalKey _meterSpotKey = GlobalKey();
  final GlobalKey _meterLogToRollKey = GlobalKey();
  bool _meterIntroScheduled = false;

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

  void _checkCameraVisibility() {
    if (!mounted) return;

    // Prefer the shell’s index — [homeTabIndexProvider] can desync (e.g. first frame), which
    // left the camera off and produced a blank meter tab for free users.
    final shell = StatefulNavigationShell.maybeOf(context);
    final isTabActive = shell != null
        ? shell.currentIndex == 2
        : ref.read(homeTabIndexProvider) == 2;
    final isAppResumed = _lifecycleState == AppLifecycleState.resumed;

    final shouldRun = isTabActive && isAppResumed;
    
    if (shouldRun && !_isCameraInitialized && _controller == null) {
      debugPrint('[MeterView] Starting camera - Tab Active & App Resumed');
      _setupCamera();
    } else if (!shouldRun && _controller != null) {
      debugPrint('[MeterView] Stopping camera - Visibility lost');
      _disposeCamera();
    }
  }

  Future<void> _disposeCamera() async {
    _metadataTimer?.cancel();
    _metadataTimer = null;
    final controller = _controller;
    _controller = null;
    if (mounted) setState(() => _isCameraInitialized = false);
    if (controller != null) await controller.dispose();
  }

  static const _metadataChannel = MethodChannel('com.halide/camera_metadata');

  Future<void> _setupCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();

      // Bind iOS native metadata to the **same** AVCaptureDevice as the Flutter preview.
      // Without this, DiscoverySession returns a different device → ISO/shutter often 0 → EV 0 → wrong 8s.
      try {
        await _metadataChannel.invokeMethod('setActiveCaptureDevice', {
          'deviceId': _controller!.description.name,
        });
        MeterDebugLog.log('setActiveCaptureDevice: ${_controller!.description.name}');
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
        await _controller!.setExposureMode(ExposureMode.auto);
        await _controller!.setExposurePoint(const Offset(0.5, 0.5));
      } catch (_) {}

      // iOS: first launch after granting permission sometimes leaves preview paused until resumed.
      try {
        await _controller!.resumePreview();
      } catch (_) {}

      if (mounted) setState(() => _isCameraInitialized = true);

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
    final stops = <double>[1.0, 1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0];
    double selected = current.aperture;
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
              const Text('APERTURE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: stops.map((v) {
                  final isSelected = v == selected;
                  return InkWell(
                    onTap: () {
                      setSheet(() => selected = v);
                      ref.read(meterProvider.notifier).updateAperture(v);
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: _pickerChip('f/${v.toStringAsFixed(v == 2.0 ? 0 : 1)}', isSelected),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
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
    // Watch tab index to trigger camera start/stop
    ref.listen<int>(homeTabIndexProvider, (previous, next) {
      _checkCameraVisibility();
    });

    final meterState = ref.watch(meterProvider);
    final plan = ref.watch(userPlanProvider);
    final isPro = plan.isPro;

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
            // Spot Metering Target — tap to re-meter and return to Aperture Priority
            Align(
              alignment: const Alignment(0, -0.3),
              child: GestureDetector(
                key: _meterSpotKey,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(meterProvider.notifier).resetToAperturePriority();
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: meterState.isLocked
                          ? Colors.orangeAccent
                          : meterState.lastChanged == ExposureControl.shutter
                              ? Colors.blueAccent.withOpacity(0.8)
                              : Colors.white54,
                      width: 1.5,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Overlay
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: GlassPanel(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _infoColumn('LUX', '~${meterState.lux.toStringAsFixed(0)}'),
                          _infoColumn('EV', meterState.ev.toStringAsFixed(1), onTap: _showEvPicker),
                          _infoColumn('ISO', meterState.iso.toStringAsFixed(0), onTap: _showIsoPicker),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // AE stability indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: meterState.isLocked
                                  ? Colors.orangeAccent
                                  : meterState.isAeStable
                                      ? const Color(0xFF4ADE80)
                                      : Colors.white24,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            meterState.isLocked
                                ? 'LOCKED'
                                : meterState.isAeStable
                                    ? 'STABLE'
                                    : 'METERING…',
                            style: TextStyle(
                              color: meterState.isLocked
                                  ? Colors.orangeAccent
                                  : meterState.isAeStable
                                      ? const Color(0xFF4ADE80)
                                      : Colors.white38,
                              fontSize: 9,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _valueColumn('f/', meterState.aperture.toStringAsFixed(1), onTap: _showAperturePicker),
                          _valueColumn('SS', _formatShutterSpeed(meterState.shutterSpeed), onTap: _showShutterPicker),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _handleLockToggle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: meterState.isLocked ? Colors.orangeAccent : Colors.white10,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          meterState.isLocked ? 'UNLOCK' : 'LOCK EXPOSURE',
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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

  Widget _infoColumn(String label, String value, {VoidCallback? onTap}) {
    final child = Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300)),
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
        Text(prefix, style: const TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w200)),
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

/// Edge-to-edge preview. [Center] + [AspectRatio] letterboxes on portrait screens; this crops like a camera app.
class _MeterFullBleedPreview extends StatelessWidget {
  final CameraController controller;

  const _MeterFullBleedPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ar = controller.value.aspectRatio;
        if (ar <= 0 || !ar.isFinite) {
          return Center(
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CameraPreview(controller),
            ),
          );
        }
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxWidth / ar,
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
