import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:frontend/config/app_config.dart';
import 'package:frontend/core/models/notification_model.dart';
import 'package:frontend/core/providers/notification_provider.dart';
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

  Future<void> _flushPendingToCloud() async {
    if (_pendingProCloud.isEmpty) return;
    final plan = ref.read(userPlanProvider);
    if (plan != UserPlan.pro) {
      _pendingProCloud.clear();
      return;
    }

    for (final e in _pendingProCloud.entries) {
      final p = e.value;
      await _editService.replaceCloudImage(
        rollId: widget.rollId,
        imageId: p.imageId,
        jpegFile: File(p.localPath),
      );
    }
    _pendingProCloud.clear();

    if (!mounted) return;
    ref.invalidate(rollDetailProvider(widget.rollId));
  }

  Future<void> _exitViewer() async {
    await _flushPendingToCloud();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

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

  String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> _shareCurrentImage() async {
    try {
      final path = await _ensureLocalOrTempFileForExport();
      if (path == null || !File(path).existsSync()) {
        ref.read(notificationProvider.notifier).show(
              'IMAGE NOT AVAILABLE OFFLINE YET. WAIT FOR DOWNLOAD OR CHECK CONNECTION.',
              type: NotificationType.warning,
            );
        return;
      }
      final mime = _mimeTypeForPath(path);
      final name = p.basename(path);
      await Share.shareXFiles([
        XFile(path, mimeType: mime, name: name),
      ]);
    } catch (e, st) {
      debugPrint('[FullScreenViewer] share failed: $e\n$st');
      ref.read(notificationProvider.notifier).show(
            'COULDN\'T SHARE IMAGE.',
            type: NotificationType.error,
          );
    }
  }

  Future<void> _saveCurrentToPhotos() async {
    try {
      var granted = await Gal.hasAccess(toAlbum: true);
      if (!granted) {
        granted = await Gal.requestAccess(toAlbum: true);
      }
      if (!granted) {
        ref.read(notificationProvider.notifier).show(
              'PHOTOS LIBRARY ACCESS DENIED. ENABLE IN SETTINGS.',
              type: NotificationType.error,
            );
        return;
      }
      final path = await _ensureLocalOrTempFileForExport();
      if (path == null || !File(path).existsSync()) {
        ref.read(notificationProvider.notifier).show(
              'IMAGE NOT AVAILABLE OFFLINE YET. WAIT FOR DOWNLOAD OR CHECK CONNECTION.',
              type: NotificationType.warning,
            );
        return;
      }
      await Gal.putImage(path);
      if (!mounted) return;
      ref.read(notificationProvider.notifier).show(
            'SAVED TO PHOTOS.',
            type: NotificationType.success,
          );
    } on GalException catch (e, st) {
      debugPrint('[FullScreenViewer] gal save: $e\n$st');
      ref.read(notificationProvider.notifier).show(
            'COULDN\'T SAVE TO PHOTOS.',
            type: NotificationType.error,
          );
    } catch (e, st) {
      debugPrint('[FullScreenViewer] save to photos failed: $e\n$st');
      ref.read(notificationProvider.notifier).show(
            'COULDN\'T SAVE TO PHOTOS.',
            type: NotificationType.error,
          );
    }
  }

  void _showHalideDebugLogs() {
    showHalideDebugLogSheet(
      context,
      title: 'HALIDE DEBUG LOG',
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
    final url = widget.imageUrls[_currentIndex];
    final canRotate = url.startsWith('http') ||
        url.startsWith('/') ||
        url.startsWith('file://');
    if (!canRotate) {
      ref.read(notificationProvider.notifier).show(
            'CANNOT ROTATE THIS IMAGE TYPE.',
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
            'COULD NOT ROTATE IMAGE.',
            type: NotificationType.error,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(userPlanProvider);
    final isPro = plan == UserPlan.pro;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await _flushPendingToCloud();
        if (context.mounted) {
          Navigator.of(context).pop(result);
        }
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
                        ),
                        if (AppConfig.showInAppDiagnostics) ...[
                          IconButton(
                            tooltip: 'Debug logs (Sync, Meter, …)',
                            onPressed: _rotating ? null : _showHalideDebugLogs,
                            icon: const Icon(Icons.terminal, color: Color(0xFFFFA07A), size: 22),
                          ),
                          IconButton(
                            tooltip: 'Image URL & cache',
                            onPressed: _rotating ? null : _showCurrentImageUrlDiagnostics,
                            icon: const Icon(Icons.link, color: Color(0xFFFFA07A), size: 22),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          '${_currentIndex + 1} / ${widget.imageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_rotating)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          )
                        else ...[
                          IconButton(
                            tooltip: 'Share',
                            onPressed: _shareCurrentImage,
                            icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
                          ),
                          IconButton(
                            tooltip: 'Save to Photos',
                            onPressed: _saveCurrentToPhotos,
                            icon: const Icon(Icons.download_rounded, color: Colors.white),
                          ),
                          IconButton(
                            tooltip: '90° counter-clockwise',
                            onPressed: () => _applyRotation(-1),
                            icon: const Icon(Icons.rotate_left, color: Colors.white),
                          ),
                          IconButton(
                            tooltip: '90° clockwise',
                            onPressed: () => _applyRotation(1),
                            icon: const Icon(Icons.rotate_right, color: Colors.white),
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
                      'Edits save on this device. Upgrade to Pro to sync rotated images to the cloud.',
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
                      'Unsaved cloud changes: ${_pendingProCloud.length} — leaving uploads to Halide Cloud.',
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
                                'ISO ${widget.iso}',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                        if (widget.dateScanned != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Scanned: ${widget.dateScanned!.toLocal().toString().split(' ')[0]}',
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

    final shotIndex = imageIndex;
    if (shotIndex < 0 || shotIndex >= widget.shots!.length) return const SizedBox.shrink();

    final shot = widget.shots![shotIndex];
    final aperture = shot['aperture'];
    final speed = shot['shutter_speed'];

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          Row(
            children: [
              _infoTile(Icons.camera_rounded, aperture != null ? 'f/$aperture' : '---'),
              const SizedBox(width: 24),
              _infoTile(Icons.timer_outlined, speed ?? '---'),
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
