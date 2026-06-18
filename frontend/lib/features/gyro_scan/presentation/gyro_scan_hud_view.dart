import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../models/roll.dart';
import '../../../models/roll_status.dart';
import '../../../core/models/notification_model.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/roll_provider.dart';
import '../../../services/guidance_service.dart';
import '../../../widgets/guidance/lab_drive_sync_guidance.dart';
import '../logic/gyro_scan_constants.dart';
import '../logic/gyro_scan_controller.dart';
import '../services/gyro_scan_cache_service.dart';
import '../services/gyro_scan_session_service.dart';
import '../services/gyro_scan_sync_service.dart';
import 'widgets/gyro_hud_overlay.dart';

/// Full-screen gyro-assisted negative film scanner with live positive preview.
class GyroScanHudView extends ConsumerStatefulWidget {
  final String rollId;

  const GyroScanHudView({super.key, required this.rollId});

  @override
  ConsumerState<GyroScanHudView> createState() => _GyroScanHudViewState();
}

class _GyroScanHudViewState extends ConsumerState<GyroScanHudView> {
  final GyroScanController _gyro = GyroScanController();

  CameraController? _controller;
  bool _cameraReady = false;

  int _currentFrameIndex = 0;
  int _shotOffset = 0;
  int _maxFrames = 36;
  final Set<int> _capturedFrames = {};
  final Map<int, String> _frameThumbPaths = {};

  /// `true` = live camera; `false` = reviewing a captured frame in the carousel.
  bool _isLiveMode = true;

  /// `true` = orange-mask inversion (positive); `false` = raw negative.
  bool _positiveViewEnabled = true;

  bool _aeAfLocked = false;
  bool _capturing = false;
  bool _showCaptureFlash = false;
  bool _thumbsLoaded = false;
  bool _gyroScanIntroScheduled = false;
  bool _endingScan = false;
  bool _sessionPrepared = false;

  final GlobalKey _negativeViewKey = GlobalKey();
  final GlobalKey _positiveViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _gyro.addListener(_onGyroUpdate);
    _gyro.start();
    _initCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleGyroScanIntroIfNeeded());
  }

  @override
  void dispose() {
    _gyro.removeListener(_onGyroUpdate);
    _gyro.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _prepareScanSession(Roll roll) async {
    await GyroScanSessionService.instance.markUnfinished(widget.rollId);
    if (roll.status != RollStatus.scanned) return;

    final user = ref.read(userProvider);
    final token = await user?.getIdToken();
    if (token == null) return;

    try {
      await ref.read(rollServiceProvider).pauseGyroScanSession(token, widget.rollId);
      ref.invalidate(rollDetailProvider(widget.rollId));
      ref.invalidate(dashboardRollsProvider);
    } catch (e) {
      debugPrint('[GyroScan] could not pause session: $e');
    }
  }

  Future<void> _loadExistingThumbs(int shotOffset) async {
    final thumbs = await GyroScanCacheService.instance.listLocalThumbs(widget.rollId);
    if (!mounted) return;
    setState(() {
      for (final (frameNum, path) in thumbs) {
        final index = frameNum - shotOffset;
        if (index >= 0) {
          _capturedFrames.add(index);
          _frameThumbPaths[index] = path;
        }
      }
      // Resume at the first uncaptured frame.
      for (var i = 0; i < _maxFrames; i++) {
        if (!_capturedFrames.contains(i)) {
          _currentFrameIndex = i;
          break;
        }
      }
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted || cameras.isEmpty) return;
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final c = CameraController(
        back,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = c;
      await c.initialize();
      if (!mounted || _controller != c) return;

      try {
        await c.setExposureMode(ExposureMode.auto);
        await c.setFocusMode(FocusMode.auto);
        await c.setExposurePoint(const Offset(0.5, 0.5));
        await c.setFocusPoint(const Offset(0.5, 0.5));
      } catch (e) {
        debugPrint('[GyroScan] initial AE/AF: $e');
      }

      setState(() => _cameraReady = true);
      _scheduleGyroScanIntroIfNeeded();
    } catch (e) {
      debugPrint('[GyroScan] camera init failed: $e');
    }
  }

  void _onGyroUpdate() {
    if (!mounted || !_isLiveMode) return;
    final snap = _gyro.snapshot;
    _handleAutoSnap(snap);
    setState(() {});
  }

  Future<void> _lockAeAfIfNeeded(double theta) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _aeAfLocked) return;
    if (theta > gyroAeAfLockThetaDeg) return;
    try {
      await c.setExposurePoint(const Offset(0.5, 0.5));
      await c.setFocusPoint(const Offset(0.5, 0.5));
      await c.setExposureMode(ExposureMode.locked);
      await c.setFocusMode(FocusMode.locked);
      _aeAfLocked = true;
    } catch (e) {
      debugPrint('[GyroScan] AE/AF lock failed: $e');
    }
  }

  Future<void> _unlockAeAf() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setExposureMode(ExposureMode.auto);
      await c.setFocusMode(FocusMode.auto);
      await c.setExposurePoint(const Offset(0.5, 0.5));
      await c.setFocusPoint(const Offset(0.5, 0.5));
    } catch (_) {}
    _aeAfLocked = false;
  }

  void _handleAutoSnap(GyroScanSensorSnapshot snap) {
    if (_capturing || !_cameraReady || !_isLiveMode) return;

    if (snap.thetaDeg > gyroAeAfLockThetaDeg) {
      if (_aeAfLocked) unawaited(_unlockAeAf());
      return;
    }

    unawaited(_lockAeAfIfNeeded(snap.thetaDeg));

    if (!snap.isAligned) return;
    unawaited(_captureFrame());
  }

  int get _frameNumber => _currentFrameIndex + _shotOffset;

  Future<void> _captureFrame() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    if (_capturedFrames.contains(_currentFrameIndex)) return;

    setState(() => _capturing = true);
    try {
      final file = await c.takePicture();
      final bytes = await file.readAsBytes();

      final paths = await GyroScanCacheService.instance.saveCapture(
        rollId: widget.rollId,
        frameNumber: _frameNumber,
        rawBytes: bytes,
      );

      await GyroScanSyncService.instance.enqueue(
        GyroScanSyncTask(
          rollId: widget.rollId,
          frameNumber: _frameNumber,
          localRawPath: paths.rawPath,
        ),
      );

      HapticFeedback.heavyImpact();

      if (mounted) {
        setState(() {
          _showCaptureFlash = true;
          _capturedFrames.add(_currentFrameIndex);
          _frameThumbPaths[_currentFrameIndex] = paths.thumbPath;
        });
        Future.delayed(const Duration(milliseconds: 180), () {
          if (mounted) setState(() => _showCaptureFlash = false);
        });
      }

      _gyro.resetAlignment();
      await _unlockAeAf();

      if (_currentFrameIndex < _maxFrames - 1 && mounted) {
        setState(() => _currentFrameIndex++);
      }

      ref.invalidate(rollGalleryPairsProvider(widget.rollId));
    } catch (e) {
      debugPrint('[GyroScan] capture failed: $e');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _onFrameSelected(int index) {
    final captured = _capturedFrames.contains(index);
    setState(() {
      _currentFrameIndex = index;
      if (captured) {
        _isLiveMode = false;
      } else {
        _isLiveMode = true;
        _gyro.resetAlignment();
        unawaited(_unlockAeAf());
      }
    });
  }

  void _returnToLive() {
    setState(() {
      _isLiveMode = true;
      _gyro.resetAlignment();
    });
    unawaited(_unlockAeAf());
  }

  /// Flush uploads, mark roll scanned when frames exist, return to roll detail gallery.
  Future<void> _endScanning() async {
    if (_endingScan) return;

    if (_capturedFrames.isEmpty) {
      if (mounted) context.pop();
      return;
    }

    setState(() => _endingScan = true);
    try {
      await GyroScanSyncService.instance.processQueueForRoll(widget.rollId);

      final user = ref.read(userProvider);
      final token = await user?.getIdToken();
      if (token != null) {
        await ref.read(rollServiceProvider).updateRollStatus(
              token,
              widget.rollId,
              'scanned',
            );
      }

      await GyroScanSessionService.instance.clearUnfinished(widget.rollId);

      ref.invalidate(rollDetailProvider(widget.rollId));
      ref.invalidate(rollGalleryPairsProvider(widget.rollId));
      ref.invalidate(dashboardRollsProvider);

      if (mounted) {
        ref.read(notificationProvider.notifier).show(
              'SCANNING COMPLETE — ${_capturedFrames.length} FRAME(S)',
              type: NotificationType.success,
            );
        context.pop();
      }
    } catch (e) {
      debugPrint('[GyroScan] end scanning failed: $e');
      if (mounted) {
        ref.read(notificationProvider.notifier).show(
              'COULD NOT FINISH SCANNING. TRY AGAIN.',
              type: NotificationType.error,
            );
      }
    } finally {
      if (mounted) setState(() => _endingScan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rollAsync = ref.watch(rollDetailProvider(widget.rollId));

    return rollAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(child: Text(e.toString(), style: const TextStyle(color: Colors.white70))),
      ),
      data: (roll) {
        _shotOffset = roll.shotOffset;
        _maxFrames = roll.maxFrames > 0 ? roll.maxFrames : 36;
        if (!_sessionPrepared) {
          _sessionPrepared = true;
          unawaited(_prepareScanSession(roll));
        }
        if (!_thumbsLoaded) {
          _thumbsLoaded = true;
          unawaited(_loadExistingThumbs(roll.shotOffset));
        }
        return _buildHud(context, roll);
      },
    );
  }

  Widget _buildHud(BuildContext context, Roll roll) {
    final snap = _gyro.snapshot;
    final showLiveFilter = _isLiveMode && _positiveViewEnabled;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isLiveMode)
            _buildLiveViewport(showLiveFilter)
          else
            _buildReviewViewport(),
          if (_isLiveMode)
            GyroHudOverlay(
              feedback: snap.feedback,
              dotOffset: snap.dotOffset,
              snapToCenter: snap.snapToCenter,
            ),
          if (_showCaptureFlash)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.85), width: 12),
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.orange.withValues(alpha: 0.18),
                    ],
                    radius: 1.2,
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, roll, snap),
                const Spacer(),
                if (!_isLiveMode) _buildReviewBanner(),
                _buildFrameCarousel(),
                const SizedBox(height: 10),
                _buildFinishBar(),
                const SizedBox(height: 8),
                _buildBottomHint(snap),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveViewport(bool applyFilter) {
    final c = _controller;
    if (!_cameraReady || c == null || !c.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white54),
            SizedBox(height: 16),
            Text('Starting camera…', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    Widget preview = CameraPreview(c);
    if (applyFilter) {
      preview = ColorFiltered(
        colorFilter: const ColorFilter.matrix(orangeMaskInversionMatrix),
        child: preview,
      );
    }

    return ClipRect(child: preview);
  }

  Widget _buildReviewViewport() {
    final thumbPath = _frameThumbPaths[_currentFrameIndex];
    if (thumbPath == null || !File(thumbPath).existsSync()) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_outlined, size: 48, color: Colors.white.withValues(alpha: 0.35)),
            const SizedBox(height: 12),
            Text(
              'Frame ${(_currentFrameIndex + _shotOffset + 1).toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Image.file(
        File(thumbPath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget _buildReviewBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _returnToLive,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_rounded, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Reviewing frame ${(_currentFrameIndex + _shotOffset + 1).toString().padLeft(2, '0')} — tap to scan live',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Roll roll, GyroScanSensorSnapshot snap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _endingScan ? null : () => context.pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Pause and return',
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  roll.title ?? '${roll.brand} ${roll.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (_isLiveMode)
                  Text(
                    'θ ${snap.thetaDeg.toStringAsFixed(2)}°',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                  ),
              ],
            ),
          ),
          if (_isLiveMode) _buildViewToggle(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            key: _negativeViewKey,
            icon: Icons.filter_frames_outlined,
            tooltip: 'Negative (raw)',
            selected: !_positiveViewEnabled,
            onTap: () => setState(() => _positiveViewEnabled = false),
          ),
          _ToggleChip(
            key: _positiveViewKey,
            icon: Icons.invert_colors_outlined,
            tooltip: 'Positive (inverted)',
            selected: _positiveViewEnabled,
            onTap: () => setState(() => _positiveViewEnabled = true),
          ),
        ],
      ),
    );
  }

  void _scheduleGyroScanIntroIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_isLiveMode) return;
      if (_gyroScanIntroScheduled) return;
      _gyroScanIntroScheduled = true;

      if (await GuidanceService.instance.hasSeenGyroScanIntro) {
        _gyroScanIntroScheduled = false;
        return;
      }

      if (_negativeViewKey.currentContext == null) {
        _gyroScanIntroScheduled = false;
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      _showGyroScanIntroStep1();
    });
  }

  Future<void> _resumeCameraPreviewIfNeeded() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.resumePreview();
    } catch (e) {
      debugPrint('[GyroScan] resumePreview: $e');
    }
    if (mounted) setState(() {});
  }

  void _showGyroScanIntroStep1() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_isLiveMode) return;
      await _resumeCameraPreviewIfNeeded();
      if (!mounted) return;
      final coach = buildSingleStepArchiveGuidance(
        targetKey: _negativeViewKey,
        identify: 'gyro_scan_negative_preview',
        contentAlign: ContentAlign.bottom,
        paddingFocus: 6,
        radius: 18,
        body:
            'Raw negative shows the film as it sits on the light table — orange base, no processing. '
            'Use this to check alignment and framing.',
        onCompleted: () {
          unawaited(_resumeCameraPreviewIfNeeded());
          Future<void>.delayed(const Duration(milliseconds: 200), () {
            if (mounted) _showGyroScanIntroStep2();
          });
        },
      );
      coach.show(context: context);
    });
  }

  void _showGyroScanIntroStep2() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_isLiveMode) return;
      await _resumeCameraPreviewIfNeeded();
      if (!mounted) return;
      final coach = buildSingleStepArchiveGuidance(
        targetKey: _positiveViewKey,
        identify: 'gyro_scan_positive_preview',
        contentAlign: ContentAlign.bottom,
        paddingFocus: 6,
        radius: 18,
        body:
            'Positive preview inverts the orange mask live so the scan looks like a finished print. '
            'This is the default for judging exposure while auto-capture runs.',
        onCompleted: () {
          unawaited(GuidanceService.instance.setGyroScanIntroSeen());
          unawaited(_resumeCameraPreviewIfNeeded());
          _gyroScanIntroScheduled = false;
        },
      );
      coach.show(context: context);
    });
  }

  Widget _buildFrameCarousel() {
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _maxFrames,
        itemBuilder: (context, index) {
          final selected = index == _currentFrameIndex;
          final captured = _capturedFrames.contains(index);
          final thumb = _frameThumbPaths[index];
          final label = (index + _shotOffset + 1).toString().padLeft(2, '0');

          return GestureDetector(
            onTap: () => _onFrameSelected(index),
            child: Container(
              width: 58,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? Colors.orange
                      : captured
                          ? Colors.green.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.2),
                  width: selected ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (captured && thumb != null)
                    Image.file(File(thumb), fit: BoxFit.cover)
                  else
                    ColoredBox(
                      color: selected
                          ? Colors.orange.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.35),
                    ),
                  Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: captured ? Colors.white : (selected ? Colors.orange : Colors.white70),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        shadows: captured
                            ? const [Shadow(color: Colors.black87, blurRadius: 4)]
                            : null,
                      ),
                    ),
                  ),
                  if (captured)
                    const Positioned(
                      right: 4,
                      top: 4,
                      child: Icon(Icons.check_circle, size: 12, color: Colors.greenAccent),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFinishBar() {
    final count = _capturedFrames.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == 0
                  ? 'Capture frames to finish'
                  : '$count / $_maxFrames captured',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _endingScan || count == 0 ? null : _endScanning,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
              disabledForegroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: _endingScan
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text(
                    'Finish scanning',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomHint(GyroScanSensorSnapshot snap) {
    if (!_isLiveMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'Historical frame — live color filter disabled',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
        ),
      );
    }

    String hint;
    switch (snap.feedback) {
      case GyroFeedback.locked:
        hint = 'Level the phone over the light table';
      case GyroFeedback.guiding:
        hint = 'Almost level — hold steady';
      case GyroFeedback.ready:
        hint = _positiveViewEnabled
            ? 'Hold steady — auto-capturing (positive view)'
            : 'Hold steady — auto-capturing (negative view)';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        hint,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.orange.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected ? Colors.orange : Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}
