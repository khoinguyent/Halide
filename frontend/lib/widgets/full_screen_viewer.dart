import 'dart:async' show unawaited;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:frontend/core/l10n/enum_l10n.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import 'package:frontend/core/models/notification_model.dart';
import 'package:frontend/config/app_config.dart';
import 'package:frontend/core/providers/notification_provider.dart';
import 'package:frontend/features/print/presentation/print_compose_view.dart';
import 'package:frontend/models/film_stock.dart';
import 'package:frontend/models/camera.dart';
import 'package:frontend/models/user_profile.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/roll_provider.dart';
import 'package:frontend/services/roll_image_edit_service.dart';
import 'package:frontend/services/local_sync_service.dart';
import 'package:frontend/widgets/debug_log_sheet.dart';
import 'package:frontend/widgets/image_url_diagnostics_sheet.dart';

import 'synced_image.dart';

class _PendingCloudRotation {
  final String localPath;
  final String imageId;

  _PendingCloudRotation({required this.localPath, required this.imageId});
}

/// Runs after the viewer pops — do not use [WidgetRef] here; use [container] only.
Future<void> _uploadPendingRotationsInBackground(
  ProviderContainer container,
  String rollId,
  Map<int, _PendingCloudRotation> pending,
  String uploadFailureMessage,
) async {
  if (pending.isEmpty) return;
  final edit = RollImageEditService();
  var failures = 0;
  for (final e in pending.entries) {
    final p = e.value;
    try {
      final ok = await edit.replaceCloudImage(
        rollId: rollId,
        imageId: p.imageId,
        jpegFile: File(p.localPath),
      );
      if (!ok) failures++;
    } catch (e, st) {
      debugPrint('[FullScreenViewer] background cloud replace: $e\n$st');
      failures++;
    }
  }
  try {
    container.invalidate(rollDetailProvider(rollId));
  } catch (_) {}
  if (failures > 0) {
    try {
      container.read(notificationProvider.notifier).show(
            uploadFailureMessage,
            type: NotificationType.error,
          );
    } catch (_) {}
  }
}

class FullScreenViewer extends ConsumerStatefulWidget {
  final String rollId;
  final List<String> imageUrls;
  /// Parallel to [imageUrls]: DB image row ids for cloud replace (Pro).
  final List<String>? imageIds;
  final int initialIndex;
  final FilmStock? filmStock;
  final Camera? camera;
  final int? iso;
  final DateTime? dateScanned;
  final List<dynamic>? shots;
  final int shotOffset;

  const FullScreenViewer({
    Key? key,
    required this.rollId,
    required this.imageUrls,
    this.imageIds,
    this.initialIndex = 0,
    this.filmStock,
    this.camera,
    this.iso,
    this.dateScanned,
    this.shots,
    this.shotOffset = 0,
  }) : super(key: key);

  @override
  ConsumerState<FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends ConsumerState<FullScreenViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;
  int _reloadToken = 0;
  bool _rotating = false;

  final RollImageEditService _editService = RollImageEditService();

  /// Pro: rotations are uploaded to R2 when the viewer closes (batched).
  final Map<int, _PendingCloudRotation> _pendingProCloud = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
  }

  String? _imageIdAt(int index) {
    final ids = widget.imageIds;
    if (ids == null || index < 0 || index >= ids.length) return null;
    final id = ids[index];
    if (id.isEmpty) return null;
    return id;
  }

  /// Pops immediately; Pro rotation uploads to R2 run in the background. Errors-only toast.
  void _popWithAsyncCloudFlush([Object? result]) {
    final container = ProviderScope.containerOf(context);
    final rollId = widget.rollId;
    final failureMsg = halideCaps(context.l10n.couldNotUploadRotated);
    final pending = ref.read(userPlanProvider) == UserPlan.pro && _pendingProCloud.isNotEmpty
        ? Map<int, _PendingCloudRotation>.from(_pendingProCloud)
        : <int, _PendingCloudRotation>{};
    _pendingProCloud.clear();

    Navigator.of(context).pop(result);

    if (pending.isNotEmpty) {
      unawaited(_uploadPendingRotationsInBackground(container, rollId, pending, failureMsg));
    }
  }

  void _exitViewer() => _popWithAsyncCloudFlush();

  Future<String?> _resolvedLocalFilePathForCurrent() async {
    final url = widget.imageUrls[_currentIndex];
    final id = _imageIdAt(_currentIndex);
    final svc = LocalSyncService();
    var path = await svc.resolveLocalPath(
      rollId: widget.rollId,
      imageUrl: url,
      imageId: id,
      preferThumbnail: false,
    );
    path ??= await svc.ensureLocalSync(widget.rollId, url, imageId: id);
    if (path.startsWith('http')) return null;
    if (path.startsWith('file://')) return Uri.parse(path).toFilePath();
    if (path.startsWith('/')) return path;
    return null;
  }

  /// Share / Photos need a readable file. The viewer can show [Image.network] while the cache
  /// is still empty or failed; this mirrors R2 into a temp file when needed.
  Future<String?> _ensureLocalOrTempFileForExport() async {
    final url = widget.imageUrls[_currentIndex];
    final id = _imageIdAt(_currentIndex);

    final resolved = await _resolvedLocalFilePathForCurrent();
    if (resolved != null && File(resolved).existsSync()) {
      return resolved;
    }

    if (!url.startsWith('http')) {
      return null;
    }

    final tmpDir = await getTemporaryDirectory();
    final base = (id != null && id.isNotEmpty) ? 'halide_share_$id' : 'halide_share_${url.hashCode.abs()}';
    var ext = p.extension(Uri.parse(url).path);
    if (ext.isEmpty || ext.length > 6) ext = '.jpg';
    final outPath = p.join(tmpDir.path, '$base$ext');

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 120),
        headers: const {'User-Agent': 'HalideFilm/1.0 (Flutter; iOS/Android)'},
        followRedirects: true,
        maxRedirects: 8,
        validateStatus: (s) => s != null && s >= 200 && s < 400,
      ),
    );

    try {
      await dio.download(url, outPath);
    } catch (e, st) {
      debugPrint('[FullScreenViewer] export download failed: $e\n$st');
      try {
        final f = File(outPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      return null;
    }

    final file = File(outPath);
    if (!await file.exists() || !await isPlausibleImageCacheFile(file)) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      return null;
    }
    return outPath;
  }

  Future<void> _openSendAsPrint() async {
    // Free users may stamp/edit locally; send is gated inside compose.
    final imageId = _imageIdAt(_currentIndex) ?? '';
    final url = widget.imageUrls[_currentIndex];
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrintComposeView(
          rollId: widget.rollId,
          imageId: imageId,
          imageUrl: url,
        ),
      ),
    );
  }

  Future<void> _saveCurrentToPhotos() async {
    final l10n = context.l10n;
    try {
      var granted = await Gal.hasAccess(toAlbum: true);
      if (!granted) {
        granted = await Gal.requestAccess(toAlbum: true);
      }
      if (!granted) {
        ref.read(notificationProvider.notifier).show(
              halideCaps(l10n.photosAccessDenied),
              type: NotificationType.error,
            );
        return;
      }
      final path = await _ensureLocalOrTempFileForExport();
      if (path == null || !File(path).existsSync()) {
        ref.read(notificationProvider.notifier).show(
              halideCaps(l10n.imageNotAvailableOffline),
              type: NotificationType.warning,
            );
        return;
      }
      await Gal.putImage(path);
      if (!mounted) return;
      ref.read(notificationProvider.notifier).show(
            halideCaps(l10n.savedToPhotos),
            type: NotificationType.success,
          );
    } on GalException catch (e, st) {
      debugPrint('[FullScreenViewer] gal save: $e\n$st');
      ref.read(notificationProvider.notifier).show(
            halideCaps(l10n.couldNotSaveToPhotos),
            type: NotificationType.error,
          );
    } catch (e, st) {
      debugPrint('[FullScreenViewer] save to photos failed: $e\n$st');
      ref.read(notificationProvider.notifier).show(
            halideCaps(l10n.couldNotSaveToPhotos),
            type: NotificationType.error,
          );
    }
  }

  void _showHalideDebugLogs() {
    showHalideDebugLogSheet(
      context,
      title: 'AGXEL DEBUG LOG',
      channelFilter: null,
      emptyHint: '(no log lines yet — open rolls, meter, or sync images)',
    );
  }

  Future<void> _showCurrentImageUrlDiagnostics() async {
    final url = widget.imageUrls[_currentIndex];
    final id = _imageIdAt(_currentIndex);
    if (!mounted) return;
    showImageUrlDiagnosticsSheet(
      context,
      rollId: widget.rollId,
      imageUrl: url,
      imageId: id,
      preferThumbnail: false,
      requestUrlUsed: url,
    );
  }

  Future<void> _applyRotation(int quarterTurns) async {
    if (_rotating) return;
    final l10n = context.l10n;
    final url = widget.imageUrls[_currentIndex];
    final canRotate = url.startsWith('http') ||
        url.startsWith('/') ||
        url.startsWith('file://');
    if (!canRotate) {
      ref.read(notificationProvider.notifier).show(
            halideCaps(l10n.cannotRotateImageType),
            type: NotificationType.error,
          );
      return;
    }

    setState(() => _rotating = true);
    try {
      final imageId = _imageIdAt(_currentIndex);
      final path = await _editService.rotateQuarterTurnsAndSaveLocal(
        rollId: widget.rollId,
        imageUrl: url,
        quarterTurns: quarterTurns,
        imageId: imageId,
      );

      final plan = ref.read(userPlanProvider);
      final isPro = plan == UserPlan.pro;
      if (isPro && imageId != null) {
        _pendingProCloud[_currentIndex] = _PendingCloudRotation(
          localPath: path,
          imageId: imageId,
        );
      }

      // Same path as before — [Image.file] cache must be cleared or the bitmap stays stale.
      PaintingBinding.instance.imageCache.evict(FileImage(File(path)));

      setState(() {
        _reloadToken++;
        _rotating = false;
      });
    } catch (e, st) {
      debugPrint('[FullScreenViewer] rotate failed: $e\n$st');
      setState(() => _rotating = false);
      ref.read(notificationProvider.notifier).show(
            halideCaps(l10n.couldNotRotateImage),
            type: NotificationType.error,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plan = ref.watch(userPlanProvider);
    final isPro = plan == UserPlan.pro;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _popWithAsyncCloudFlush(result);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleOverlay,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: widget.imageUrls.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: SyncedImage(
                      key: ValueKey<String>('${widget.imageUrls[index]}_$_reloadToken'),
                      rollId: widget.rollId,
                      imageUrl: widget.imageUrls[index],
                      imageId: _imageIdAt(index),
                      fit: BoxFit.contain,
                      preferThumbnail: false,
                    ),
                  );
                },
              ),
              if (_showOverlay) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top,
                      left: 8,
                      right: 8,
                      bottom: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: _rotating ? null : _exitViewer,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          padding: EdgeInsets.zero,
                        ),
                        if (AppConfig.showInAppDiagnostics) ...[
                          IconButton(
                            tooltip: 'Debug logs (Sync, Meter, …)',
                            onPressed: _rotating ? null : _showHalideDebugLogs,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.terminal, color: Color(0xFFFFA07A), size: 20),
                          ),
                          IconButton(
                            tooltip: 'Image URL & cache',
                            onPressed: _rotating ? null : _showCurrentImageUrlDiagnostics,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.link, color: Color(0xFFFFA07A), size: 20),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          '${_currentIndex + 1} / ${widget.imageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_rotating)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          )
                        else ...[
                          IconButton(
                            tooltip: l10n.sendAsPrint,
                            onPressed: _openSendAsPrint,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            padding: EdgeInsets.zero,
                            icon: const _PostcardIcon(color: Colors.white, size: 22),
                          ),
                          IconButton(
                            tooltip: l10n.saveToPhotos,
                            onPressed: _saveCurrentToPhotos,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                          ),
                          IconButton(
                            tooltip: l10n.rotate90CounterClockwise,
                            onPressed: () => _applyRotation(-1),
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.rotate_left, color: Colors.white, size: 22),
                          ),
                          IconButton(
                            tooltip: l10n.rotate90Clockwise,
                            onPressed: () => _applyRotation(1),
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.rotate_right, color: Colors.white, size: 22),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!isPro)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 52,
                    left: 16,
                    right: 16,
                    child: Text(
                      l10n.editsLocalOnlyHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11),
                    ),
                  ),
                if (isPro && _pendingProCloud.isNotEmpty)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 48,
                    left: 16,
                    right: 16,
                    child: Text(
                      l10n.unsavedCloudChanges(_pendingProCloud.length),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.amber.withOpacity(0.85), fontSize: 11),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 24,
                      left: 24,
                      right: 24,
                      top: 48,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.camera != null)
                          Text(
                            widget.camera!.displayName.toUpperCase(),
                            style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (widget.filmStock != null)
                              Flexible(
                                child: Text(
                                  '${widget.filmStock!.brand} ${widget.filmStock!.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            if (widget.iso != null)
                              Text(
                                l10n.isoValue('${widget.iso}'),
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                        if (widget.dateScanned != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.scannedDate(widget.dateScanned!.toLocal().toString().split(' ')[0]),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                        if (widget.shots != null && widget.shots!.isNotEmpty)
                          _buildShotMetadataOverlay(_currentIndex),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShotMetadataOverlay(int imageIndex) {
    if (widget.shots == null || widget.shots!.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final shotIndex = imageIndex;
    if (shotIndex < 0 || shotIndex >= widget.shots!.length) return const SizedBox.shrink();

    final shot = widget.shots![shotIndex];
    final aperture = shot['aperture'];
    final speed = shot['shutter_speed'];
    final missing = l10n.apertureMissing;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          Row(
            children: [
              _infoTile(Icons.camera_rounded, aperture != null ? 'f/$aperture' : missing),
              const SizedBox(width: 24),
              _infoTile(Icons.timer_outlined, speed ?? missing),
              const Spacer(),
              if (shot['location_lat'] != null) const Icon(Icons.location_on_outlined, color: Colors.orange, size: 14),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange, size: 14),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// Landscape postcard silhouette: card + stamp square + address lines.
class _PostcardIcon extends StatelessWidget {
  const _PostcardIcon({required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PostcardIconPainter(color),
      ),
    );
  }
}

class _PostcardIconPainter extends CustomPainter {
  _PostcardIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final inset = size.width * 0.08;
    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, size.height * 0.18, size.width - inset * 2, size.height * 0.64),
      Radius.circular(size.width * 0.06),
    );
    canvas.drawRRect(card, stroke);

    // Stamp (top-right)
    final stamp = Rect.fromLTWH(
      size.width * 0.58,
      size.height * 0.28,
      size.width * 0.26,
      size.height * 0.22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(stamp, Radius.circular(size.width * 0.03)),
      stroke,
    );
    // Small photo hint inside stamp
    canvas.drawCircle(
      Offset(stamp.center.dx, stamp.center.dy),
      size.width * 0.045,
      stroke,
    );

    // Address / message lines (left)
    final lineLeft = size.width * 0.2;
    final lineRight = size.width * 0.5;
    final y0 = size.height * 0.42;
    for (var i = 0; i < 3; i++) {
      final y = y0 + i * size.height * 0.1;
      canvas.drawLine(Offset(lineLeft, y), Offset(lineRight, y), stroke);
    }

    // Tiny stamp perforations (dots)
    final dotR = size.width * 0.015;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(stamp.left - size.width * 0.04, stamp.top + stamp.height * (0.2 + i * 0.3)),
        dotR,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PostcardIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
