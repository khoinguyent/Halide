import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/enum_l10n.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import 'package:frontend/l10n/app_localizations.dart';
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
import '../../../widgets/sync_progress_banner.dart';
import '../logic/film_format.dart';
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

  /// Currently selected film format — governs frame-guide box + crop aspect.
  FilmFormat _filmFormat = FilmFormat.mm35;
  String? _rollFilmStockFormat;
  bool _filmFormatInitialized = false;

  bool _capturing = false;
  bool _processingCrop = false;
  bool _showCaptureFlash = false;
  bool _thumbsLoaded = false;
  bool _gyroScanIntroScheduled = false;

  // Focus-settle tracking.
  bool _focusRequested = false;
  bool _focusSettled = false;
  Timer? _focusSettleTimer;
  bool _endingScan = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;
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
    _focusSettleTimer?.cancel();
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

  /// Step 1 — phone is stable enough: request AF and start settle timer.
  /// Does NOT lock immediately; the camera needs time to hunt on the negative.
  Future<void> _requestFocusIfNeeded() async {
    if (_focusRequested) return;
    _focusRequested = true;
    _focusSettled = false;

    final c = _controller;
    if (c != null && c.value.isInitialized) {
      try {
        // Ensure continuous AF is running, then ask it to centre-focus.
        await c.setFocusMode(FocusMode.auto);
        await c.setExposureMode(ExposureMode.auto);
        await c.setFocusPoint(const Offset(0.5, 0.5));
        await c.setExposurePoint(const Offset(0.5, 0.5));
      } catch (e) {
        debugPrint('[GyroScan] focus request failed: $e');
      }
    }

    _focusSettleTimer?.cancel();
    _focusSettleTimer = Timer(
      const Duration(milliseconds: gyroFocusSettleMs),
      _onFocusSettled,
    );
  }

  /// Step 2 — settle timer fired: lock AE/AF now that the camera has had time
  /// to focus on the film negative.
  void _onFocusSettled() {
    if (!mounted) return;
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      c.setExposureMode(ExposureMode.locked).catchError((_) {});
      c.setFocusMode(FocusMode.locked).catchError((_) {});
    }
    if (mounted) setState(() => _focusSettled = true);
  }

  /// Reset focus state (e.g. phone drifted, or after a capture).
  Future<void> _resetFocus() async {
    _focusSettleTimer?.cancel();
    _focusRequested = false;
    _focusSettled = false;

    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setExposureMode(ExposureMode.auto);
      await c.setFocusMode(FocusMode.auto);
      await c.setFocusPoint(const Offset(0.5, 0.5));
      await c.setExposurePoint(const Offset(0.5, 0.5));
    } catch (_) {}
  }

  void _handleAutoSnap(GyroScanSensorSnapshot snap) {
    if (_capturing || !_cameraReady || !_isLiveMode) return;

    if (snap.thetaDeg > gyroAeAfLockThetaDeg) {
      // Phone drifted — reset so next stabilisation re-requests focus.
      if (_focusRequested) unawaited(_resetFocus());
      return;
    }

    // Phone stable enough — start focus hunt if not already underway.
    if (!_focusRequested) unawaited(_requestFocusIfNeeded());

    // Capture only when gyro AND focus are both ready.
    if (!snap.isAligned || !_focusSettled) return;
    unawaited(_captureFrame());
  }

  FocusState get _currentFocusState {
    final snap = _gyro.snapshot;
    if (snap.thetaDeg > gyroAeAfLockThetaDeg) return FocusState.idle;
    if (!_focusSettled) return FocusState.focusing;
    return FocusState.settled;
  }

  int get _frameNumber => _currentFrameIndex + _shotOffset;

  Future<void> _captureFrame() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    if (_capturedFrames.contains(_currentFrameIndex)) return;

    setState(() => _capturing = true);
    try {
      final file = await c.takePicture();

      // Instant tactile + visual feedback — don't wait for crop to finish.
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _showCaptureFlash = true);
        Future.delayed(const Duration(milliseconds: 180), () {
          if (mounted) setState(() => _showCaptureFlash = false);
        });
      }

      final bytes = await file.readAsBytes();

      // Deterministic crop + inversion in a worker isolate.
      if (mounted) setState(() => _processingCrop = true);

      final screen = MediaQuery.sizeOf(context);
      final crop = _filmFormat.normalizedFrameGuideRect(screen);

      final paths = await GyroScanCacheService.instance.saveCapture(
        rollId: widget.rollId,
        frameNumber: _frameNumber,
        rawBytes: bytes,
        cropTop: crop.top,
        cropLeft: crop.left,
        cropWidth: crop.width,
        cropHeight: crop.height,
      );

      if (mounted) setState(() => _processingCrop = false);

      await GyroScanSyncService.instance.enqueue(
        GyroScanSyncTask(
          rollId: widget.rollId,
          frameNumber: _frameNumber,
          localRawPath: paths.rawPath,
        ),
      );

      if (mounted) {
        setState(() {
          _capturedFrames.add(_currentFrameIndex);
          _frameThumbPaths[_currentFrameIndex] = paths.thumbPath;
        });
      }

      _gyro.resetAlignment();
      await _resetFocus();

      if (_currentFrameIndex < _maxFrames - 1 && mounted) {
        setState(() => _currentFrameIndex++);
      }

      ref.invalidate(rollGalleryPairsProvider(widget.rollId));
    } catch (e) {
      debugPrint('[GyroScan] capture failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
          _processingCrop = false;
        });
      }
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
        unawaited(_resetFocus());
      }
    });
  }

  void _returnToLive() {
    setState(() {
      _isLiveMode = true;
      _gyro.resetAlignment();
    });
    unawaited(_resetFocus());
  }

  /// Flush uploads, mark roll scanned when frames exist, return to roll detail gallery.
  Future<void> _endScanning() async {
    if (_endingScan) return;

    if (_capturedFrames.isEmpty) {
      if (mounted) context.pop();
      return;
    }

    setState(() {
      _endingScan = true;
      _uploadDone = 0;
      _uploadTotal = 0;
    });
    try {
      await GyroScanSyncService.instance.processQueueForRoll(
        widget.rollId,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _uploadDone = done;
            _uploadTotal = total;
          });
        },
      );

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
              halideCaps(context.l10n.scanningCompleteFrames(_capturedFrames.length)),
              type: NotificationType.success,
            );
        context.pop();
      }
    } catch (e) {
      debugPrint('[GyroScan] end scanning failed: $e');
      if (mounted) {
        ref.read(notificationProvider.notifier).show(
              halideCaps(context.l10n.couldNotFinishScanning),
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
        _applyFilmFormatFromRoll(roll);
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

  void _applyFilmFormatFromRoll(Roll roll) {
    _rollFilmStockFormat = roll.filmFormat;
    if (_filmFormatInitialized) return;
    _filmFormatInitialized = true;
    _filmFormat = FilmFormat.fromFilmStockFormat(roll.filmFormat);
  }

  Widget _buildHud(BuildContext context, Roll roll) {
    final l10n = context.l10n;
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
            FilmFrameOverlay(
              format: _filmFormat,
              feedback: snap.feedback,
              dotOffset: snap.dotOffset,
              snapToCenter: snap.snapToCenter,
              focusState: _currentFocusState,
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
          if (_processingCrop)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 0,
              right: 0,
              child: Center(
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.processing,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, roll, snap),
                const Spacer(),
                if (!_isLiveMode) _buildReviewBanner(l10n),
                _buildFrameCarousel(),
                const SizedBox(height: 10),
                _buildFinishBar(l10n),
                const SizedBox(height: 8),
                _buildBottomHint(snap, l10n),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveViewport(bool applyFilter) {
    final l10n = context.l10n;
    final c = _controller;
    if (!_cameraReady || c == null || !c.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white54),
            SizedBox(height: 16),
            Text(l10n.startingCamera, style: TextStyle(color: Colors.white54)),
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
    final l10n = context.l10n;
    final thumbPath = _frameThumbPaths[_currentFrameIndex];
    if (thumbPath == null || !File(thumbPath).existsSync()) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_outlined, size: 48, color: Colors.white.withValues(alpha: 0.35)),
            const SizedBox(height: 12),
            Text(
              l10n.frameNumber((_currentFrameIndex + _shotOffset + 1).toString().padLeft(2, '0')),
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

  Widget _buildReviewBanner(AppLocalizations l10n) {
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
                  l10n.reviewingFrameTapLive(
                    (_currentFrameIndex + _shotOffset + 1).toString().padLeft(2, '0'),
                  ),
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
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _endingScan ? null : () => context.pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: l10n.pauseAndReturn,
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
          if (_isLiveMode) ...[
            _buildFormatBadge(),
            const SizedBox(width: 4),
            _buildViewToggle(),
          ],
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// Small tappable badge showing the current film format — opens the picker.
  Widget _buildFormatBadge() {
    final canPickSubformat = FilmFormat.isMediumFilmStock(_rollFilmStockFormat);

    return GestureDetector(
      onTap: canPickSubformat ? _showFormatPicker : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.55), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.crop_rounded, size: 13, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              _filmFormat.shortName,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            if (canPickSubformat) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: Colors.orange.withValues(alpha: 0.8),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFormatPicker() {
    final options = FilmFormat.optionsForFilmStock(_rollFilmStockFormat);
    if (options.length <= 1) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final l10n = ctx.l10n;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.filmFormatSection,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map((fmt) => _FormatOption(
                      format: fmt,
                      selected: _filmFormat == fmt,
                      onTap: () {
                        setState(() => _filmFormat = fmt);
                        Navigator.of(ctx).pop();
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildViewToggle() {
    final l10n = context.l10n;
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
            tooltip: l10n.negativeRawTooltip,
            selected: !_positiveViewEnabled,
            onTap: () => setState(() => _positiveViewEnabled = false),
          ),
          _ToggleChip(
            key: _positiveViewKey,
            icon: Icons.invert_colors_outlined,
            tooltip: l10n.positiveInvertedTooltip,
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
        context: context,
        targetKey: _negativeViewKey,
        identify: 'gyro_scan_negative_preview',
        contentAlign: ContentAlign.bottom,
        paddingFocus: 6,
        radius: 18,
        body: context.l10n.guidanceGyroNegativePreview,
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
        context: context,
        targetKey: _positiveViewKey,
        identify: 'gyro_scan_positive_preview',
        contentAlign: ContentAlign.bottom,
        paddingFocus: 6,
        radius: 18,
        body: context.l10n.guidanceGyroPositivePreview,
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

  Widget _buildFinishBar(AppLocalizations l10n) {
    final count = _capturedFrames.length;
    final uploadProgress =
        _endingScan && _uploadTotal > 0 ? (_uploadDone / _uploadTotal).clamp(0.0, 1.0) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_endingScan) ...[
            SyncProgressBanner(
              label: _uploadTotal > 0
                  ? 'Uploading frames $_uploadDone of $_uploadTotal…'
                  : 'Finishing scan — uploading frames…',
              progress: uploadProgress,
              accentColor: Colors.orange,
              compact: true,
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  count == 0
                      ? l10n.captureFramesToFinish
                      : l10n.framesCapturedProgress(count, _maxFrames),
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
                    : Text(
                        l10n.finishScanning,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomHint(GyroScanSensorSnapshot snap, AppLocalizations l10n) {
    if (!_isLiveMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          l10n.historicalFramePositive,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
        ),
      );
    }

    final String hint;
    switch (snap.feedback) {
      case GyroFeedback.locked:
        hint = l10n.levelPhoneOverTable;
      case GyroFeedback.guiding:
        hint = l10n.almostLevelHoldSteady;
      case GyroFeedback.ready:
        if (!_focusSettled) {
          hint = l10n.leveledFocusingNegative;
        } else {
          hint = _positiveViewEnabled
              ? l10n.focusedCapturingPositive
              : l10n.focusedCapturingNegative;
        }
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

// ─────────────────────────────────────────────────────────────────────────────
// Film format option row shown in the bottom-sheet picker.
// ─────────────────────────────────────────────────────────────────────────────

class _FormatOption extends StatelessWidget {
  final FilmFormat format;
  final bool selected;
  final VoidCallback onTap;

  const _FormatOption({
    required this.format,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ar = format.frameAspect;
    // Miniature frame preview: fixed height 32, width scaled to aspect ratio.
    const previewH = 32.0;
    final previewW = (ar >= 1.0 ? previewH * ar : previewH * ar)
        .clamp(20.0, 56.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            // Mini frame preview.
            Container(
              width: 60,
              alignment: Alignment.center,
              child: Container(
                width: previewW,
                height: previewH,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected ? Colors.orange : Colors.white38,
                    width: selected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(2),
                  color: selected
                      ? Colors.orange.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    format.displayName,
                    style: TextStyle(
                      color: selected ? Colors.orange : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    format.isMediumFormat
                        ? l10n.mediumFormatDimensions(_dimensionLabel(format))
                        : l10n.format35mmDimensions(_dimensionLabel(format)),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, color: Colors.orange, size: 20),
          ],
        ),
      ),
    );
  }

  String _dimensionLabel(FilmFormat fmt) => switch (fmt) {
        FilmFormat.mm35      => '36 × 24 mm',
        FilmFormat.mm120_645 => '60 × 45 mm',
        FilmFormat.mm120_66  => '60 × 60 mm',
        FilmFormat.mm120_67  => '60 × 70 mm',
      };
}

// ─────────────────────────────────────────────────────────────────────────────

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
