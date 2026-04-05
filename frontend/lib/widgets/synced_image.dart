import 'dart:io';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../core/widgets/image_placeholder.dart';
import '../services/local_sync_service.dart';
import 'image_url_diagnostics_sheet.dart';

/// Loads a roll frame: **local file** (indexed by [imageId] or legacy basename), else **R2/network**.
/// When local is missing, triggers a background download and rebuilds when ready.
class SyncedImage extends StatefulWidget {
  final String rollId;
  final String imageUrl;
  final String? imageId;
  final BoxFit fit;

  /// Grid / strip: prefer local thumb, then network thumb, then full res fallback.
  /// Full-screen viewer: false (local full file, then full network).
  final bool preferThumbnail;

  const SyncedImage({
    Key? key,
    required this.rollId,
    required this.imageUrl,
    this.imageId,
    this.fit = BoxFit.cover,
    this.preferThumbnail = false,
  }) : super(key: key);

  @override
  State<SyncedImage> createState() => _SyncedImageState();
}

class _SyncedImageState extends State<SyncedImage> {
  static const _netHeaders = {'User-Agent': 'HalideFilm/1.0 (Flutter; iOS/Android)'};

  String? _resolvedLocalPath;
  bool _downloadAttempted = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(SyncedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.imageId != widget.imageId ||
        oldWidget.preferThumbnail != widget.preferThumbnail) {
      _resolvedLocalPath = null;
      _downloadAttempted = false;
      _resolve();
    }
  }

  String _effectiveRequestUrl() {
    if (!widget.preferThumbnail) return widget.imageUrl;
    return thumbUrlForFullImageUrl(widget.imageUrl);
  }

  Future<void> _resolve() async {
    final svc = LocalSyncService();
    final primaryUrl = _effectiveRequestUrl();

    if (primaryUrl.startsWith('/') || primaryUrl.startsWith('file://')) {
      final path =
          primaryUrl.startsWith('file://') ? Uri.parse(primaryUrl).toFilePath() : primaryUrl;
      if (mounted) setState(() => _resolvedLocalPath = path);
      return;
    }

    final existing = await svc.resolveLocalPath(
      rollId: widget.rollId,
      imageUrl: widget.imageUrl,
      imageId: widget.imageId,
      preferThumbnail: widget.preferThumbnail,
    );
    if (existing != null && mounted) {
      setState(() => _resolvedLocalPath = existing);
      return;
    }

    if (!primaryUrl.startsWith('http')) {
      return;
    }

    if (!_downloadAttempted) {
      _downloadAttempted = true;
      final result = await svc.ensureLocalSync(
        widget.rollId,
        widget.imageUrl,
        imageId: widget.imageId,
        preferThumbnail: widget.preferThumbnail,
      );
      if (!mounted) return;
      if (result.startsWith('http')) {
        setState(() {});
        return;
      }
      final f = File(result.startsWith('file://') ? Uri.parse(result).toFilePath() : result);
      if (await f.exists()) {
        setState(() => _resolvedLocalPath = f.path);
      } else {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryUrl = _effectiveRequestUrl();
    final local = _resolvedLocalPath;

    Widget core;
    if (local != null && local.startsWith('/')) {
      core = Image.file(
        File(local),
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) =>
            _buildNetworkLayer(primaryUrl, tryFullFallback: widget.preferThumbnail),
      );
    } else {
      core = _buildNetworkLayer(primaryUrl, tryFullFallback: widget.preferThumbnail);
    }

    if (!AppConfig.showInAppDiagnostics) {
      return core;
    }

    return GestureDetector(
      onLongPress: () {
        showImageUrlDiagnosticsSheet(
          context,
          rollId: widget.rollId,
          imageUrl: widget.imageUrl,
          imageId: widget.imageId,
          preferThumbnail: widget.preferThumbnail,
          requestUrlUsed: primaryUrl,
        );
      },
      child: core,
    );
  }

  Widget _buildNetworkLayer(String requestUrl, {required bool tryFullFallback}) {
    if (!requestUrl.startsWith('http')) {
      if (tryFullFallback && widget.preferThumbnail && widget.imageUrl.startsWith('http')) {
        return _buildFullResNetworkOnly();
      }
      return const HalideImagePlaceholder();
    }

    return Image.network(
      requestUrl,
      fit: widget.fit,
      headers: _netHeaders,
      errorBuilder: (context, error, stackTrace) {
        if (tryFullFallback &&
            widget.preferThumbnail &&
            requestUrl != widget.imageUrl &&
            widget.imageUrl.startsWith('http')) {
          return Image.network(
            widget.imageUrl,
            fit: widget.fit,
            headers: _netHeaders,
            errorBuilder: (c, e, s) => const HalideImagePlaceholder(),
          );
        }
        return const HalideImagePlaceholder();
      },
    );
  }

  Widget _buildFullResNetworkOnly() {
    if (!widget.imageUrl.startsWith('http')) {
      return const HalideImagePlaceholder();
    }
    return Image.network(
      widget.imageUrl,
      fit: widget.fit,
      headers: _netHeaders,
      errorBuilder: (context, error, stackTrace) => const HalideImagePlaceholder(),
    );
  }
}
