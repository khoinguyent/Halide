import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Returns true if [file] is non-trivial size and starts with JPEG or PNG magic bytes.
Future<bool> isPlausibleImageCacheFile(File file) async {
  try {
    final len = await file.length();
    if (len < 32) return false;
    final raf = await file.open();
    try {
      final head = await raf.read(12);
      if (head.length < 3) return false;
      if (head[0] == 0xff && head[1] == 0xd8) return true;
      if (head.length >= 8 &&
          head[0] == 0x89 &&
          head[1] == 0x50 &&
          head[2] == 0x4e &&
          head[3] == 0x47) {
        return true;
      }
      return false;
    } finally {
      await raf.close();
    }
  } catch (_) {
    return false;
  }
}

/// Maps a full-resolution object URL to the companion thumbnail URL (R2 convention).
String thumbUrlForFullImageUrl(String fullUrl) {
  if (!fullUrl.startsWith('http')) return fullUrl;
  final lower = fullUrl.toLowerCase();
  if (lower.endsWith('.jpg')) {
    return fullUrl.replaceFirst(RegExp(r'\.jpg$', caseSensitive: false), '_thumb.jpg');
  }
  if (lower.endsWith('.jpeg')) {
    return fullUrl.replaceFirst(RegExp(r'\.jpeg$', caseSensitive: false), '_thumb.jpeg');
  }
  if (lower.endsWith('.png')) {
    return fullUrl.replaceFirst(RegExp(r'\.png$', caseSensitive: false), '_thumb.png');
  }
  return fullUrl;
}

class LocalSyncService {
  final Dio _dio = Dio();

  /// Ensures a network image is available locally.
  /// Returns the local file path if successful or already exists.
  /// Returns the original URL if it's already local or download fails.
  Future<String> ensureLocalSync(String rollId, String imageUrl) async {
    if (imageUrl.startsWith('/') || imageUrl.startsWith('file://')) {
      return imageUrl;
    }

    if (!imageUrl.startsWith('http')) {
      return imageUrl;
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(Uri.parse(imageUrl).path);
      if (fileName.isEmpty) return imageUrl;

      final localDir = Directory(p.join(docDir.path, 'scans', rollId));
      if (!await localDir.exists()) {
        await localDir.create(recursive: true);
      }

      final localPath = p.join(localDir.path, fileName);
      final file = File(localPath);

      if (await file.exists()) {
        if (await isPlausibleImageCacheFile(file)) {
          return localPath;
        }
        try {
          await file.delete();
        } catch (_) {}
        debugPrint('[LocalSync] Removed invalid cache, re-downloading: $fileName');
      }

      debugPrint('[LocalSync] Downloading $imageUrl to $localPath');
      final response = await _dio.download(
        imageUrl,
        localPath,
        options: Options(
          validateStatus: (s) => s != null && s >= 200 && s < 300,
        ),
      );
      if (response.statusCode != 200) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
        debugPrint('[LocalSync] HTTP ${response.statusCode} for $imageUrl');
        return imageUrl;
      }
      if (!await isPlausibleImageCacheFile(file)) {
        try {
          await file.delete();
        } catch (_) {}
        debugPrint('[LocalSync] Downloaded body is not a valid image: $imageUrl');
        return imageUrl;
      }

      return localPath;
    } catch (e) {
      debugPrint('[LocalSync] Failed to sync $imageUrl: $e');
      return imageUrl;
    }
  }

  /// Prefetches full-resolution files in bounded parallel batches.
  Future<void> syncRollParallel(
    String rollId,
    List<String> imageUrls, {
    int concurrency = 6,
  }) async {
    final urls = imageUrls.where((u) => u.trim().isNotEmpty).toList();
    for (var i = 0; i < urls.length; i += concurrency) {
      final end = i + concurrency > urls.length ? urls.length : i + concurrency;
      final batch = urls.sublist(i, end);
      await Future.wait(batch.map((u) => ensureLocalSync(rollId, u)));
    }
  }

  /// Prefetches thumbnail objects (when URLs follow `*_thumb.jpg` convention).
  Future<void> prefetchThumbnailsParallel(
    String rollId,
    List<String> fullImageUrls, {
    int concurrency = 8,
  }) async {
    final thumbs = <String>[];
    for (final u in fullImageUrls) {
      final t = thumbUrlForFullImageUrl(u);
      if (t != u) thumbs.add(t);
    }
    for (var i = 0; i < thumbs.length; i += concurrency) {
      final end = i + concurrency > thumbs.length ? thumbs.length : i + concurrency;
      final batch = thumbs.sublist(i, end);
      await Future.wait(batch.map((u) => ensureLocalSync(rollId, u)));
    }
  }

  /// Sequential prefetch (legacy).
  Future<void> syncRoll(String rollId, List<String> imageUrls) async {
    await syncRollParallel(rollId, imageUrls, concurrency: 1);
  }
}
