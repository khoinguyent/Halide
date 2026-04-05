import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/widgets/image_placeholder.dart';
import '../services/local_sync_service.dart';

class SyncedImage extends StatelessWidget {
  final String rollId;
  final String imageUrl;
  final BoxFit fit;

  /// Grid / strip: prefer local thumb, then network thumb, then full res fallback.
  /// Full-screen viewer: false (local full file, then full network).
  final bool preferThumbnail;

  const SyncedImage({
    Key? key,
    required this.rollId,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.preferThumbnail = false,
  }) : super(key: key);

  String _effectiveRequestUrl() {
    if (!preferThumbnail) return imageUrl;
    return thumbUrlForFullImageUrl(imageUrl);
  }

  Future<String?> _getLocalPathForUrl(String requestUrl) async {
    if (requestUrl.startsWith('/') || requestUrl.startsWith('file://')) {
      return requestUrl.startsWith('file://')
          ? Uri.parse(requestUrl).toFilePath()
          : requestUrl;
    }
    if (!requestUrl.startsWith('http')) return null;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(Uri.parse(requestUrl).path);
      if (fileName.isEmpty) return null;

      final localPath = p.join(docDir.path, 'scans', rollId, fileName);
      final file = File(localPath);
      if (await file.exists()) {
        if (await isPlausibleImageCacheFile(file)) {
          return localPath;
        }
        try {
          await file.delete();
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final primaryUrl = _effectiveRequestUrl();

    return FutureBuilder<String?>(
      future: _getLocalPathForUrl(primaryUrl),
      builder: (context, snapshot) {
        final path = snapshot.data;

        if (path != null && path.startsWith('/')) {
          return Image.file(
            File(path),
            fit: fit,
            errorBuilder: (context, error, stackTrace) =>
                _buildNetworkLayer(primaryUrl, tryFullFallback: preferThumbnail),
          );
        }

        return _buildNetworkLayer(primaryUrl, tryFullFallback: preferThumbnail);
      },
    );
  }

  Widget _buildNetworkLayer(String requestUrl, {required bool tryFullFallback}) {
    if (!requestUrl.startsWith('http')) {
      if (tryFullFallback && preferThumbnail && imageUrl.startsWith('http')) {
        return _buildFullResNetworkOnly();
      }
      return const HalideImagePlaceholder();
    }

    return Image.network(
      requestUrl,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        if (tryFullFallback &&
            preferThumbnail &&
            requestUrl != imageUrl &&
            imageUrl.startsWith('http')) {
          return Image.network(
            imageUrl,
            fit: fit,
            errorBuilder: (c, e, s) => const HalideImagePlaceholder(),
          );
        }
        return const HalideImagePlaceholder();
      },
    );
  }

  Widget _buildFullResNetworkOnly() {
    if (!imageUrl.startsWith('http')) {
      return const HalideImagePlaceholder();
    }
    return Image.network(
      imageUrl,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => const HalideImagePlaceholder(),
    );
  }
}
