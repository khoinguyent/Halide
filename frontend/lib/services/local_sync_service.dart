import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'halide_debug_log.dart';
import 'image_cache_utils.dart';
import 'local_image_path_index.dart';

export 'image_cache_utils.dart';

String _formatDioException(DioException e) {
  final b = StringBuffer(e.type.name);
  final sc = e.response?.statusCode;
  if (sc != null) b.write(' HTTP $sc');
  final reason = e.response?.statusMessage;
  if (reason != null && reason.isNotEmpty) b.write(' ($reason)');
  if (e.message != null && e.message!.trim().isNotEmpty) {
    b.write(' — ${e.message!.trim()}');
  }
  return b.toString();
}

/// For logs when downloaded bytes are not JPEG/PNG (e.g. HTML error page).
Future<String> _describeNonImageFile(File file) async {
  try {
    final len = await file.length();
    final raf = await file.open();
    try {
      final head = await raf.read(12);
      if (head.isEmpty) return 'len=$len head=<empty>';
      final hex = head.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      final preview = String.fromCharCodes(head.take(80).where((b) => b >= 32 && b < 127));
      final ascii = preview.length > 64 ? '${preview.substring(0, 64)}…' : preview;
      return 'len=$len head=0x$hex ascii="$ascii"';
    } finally {
      await raf.close();
    }
  } catch (e) {
    return 'describe failed: $e';
  }
}

class LocalSyncService {
  LocalSyncService()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 45),
            receiveTimeout: const Duration(seconds: 120),
            headers: const {'User-Agent': 'HalideFilm/1.0 (Flutter; iOS/Android)'},
            followRedirects: true,
            maxRedirects: 8,
            validateStatus: (s) => s != null && s >= 200 && s < 400,
          ),
        );

  final Dio _dio;

  static final _downloadOptions = Options(
    headers: const {'User-Agent': 'HalideFilm/1.0 (Flutter; iOS/Android)'},
  );

  /// Best-effort local file for [imageUrl]: indexed by [imageId] first, then legacy basename cache.
  Future<String?> resolveLocalPath({
    required String rollId,
    required String imageUrl,
    String? imageId,
    required bool preferThumbnail,
  }) async {
    final docDir = await getApplicationDocumentsDirectory();
    final requestUrl = preferThumbnail ? thumbUrlForFullImageUrl(imageUrl) : imageUrl;

    if (imageId != null && imageId.isNotEmpty) {
      final key = preferThumbnail ? '${imageId}_thumb' : imageId;
      final indexed = await LocalImagePathIndex.instance.resolveAbsolute(rollId, key, docDir.path);
      if (indexed != null) {
        return indexed;
      }
    }

    if (!requestUrl.startsWith('http')) {
      return null;
    }

    final fileName = p.basename(Uri.parse(requestUrl).path);
    if (fileName.isEmpty) return null;
    final legacy = p.join(docDir.path, 'scans', rollId, fileName);
    final f = File(legacy);
    if (await f.exists() && await isPlausibleImageCacheFile(f)) {
      return legacy;
    }
    return null;
  }

  /// Ensures a network image is available locally.
  /// Returns the local file path if successful or already exists.
  /// Returns the original URL if it's already local or download fails.
  Future<String> ensureLocalSync(
    String rollId,
    String imageUrl, {
    String? imageId,
    bool preferThumbnail = false,
  }) async {
    if (imageUrl.startsWith('/') || imageUrl.startsWith('file://')) {
      return imageUrl;
    }

    if (!imageUrl.startsWith('http')) {
      return imageUrl;
    }

    final effectiveUrl = preferThumbnail ? thumbUrlForFullImageUrl(imageUrl) : imageUrl;
    if (!effectiveUrl.startsWith('http')) {
      HalideDebugLog.log(
        'Sync',
        'no separate thumb URL (same as full or invalid) roll=$rollId thumb=$preferThumbnail — skipping thumb fetch',
      );
      return imageUrl;
    }

    String? pendingDownloadPath;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final localDir = Directory(p.join(docDir.path, 'scans', rollId));
      if (!await localDir.exists()) {
        await localDir.create(recursive: true);
      }

      String localFileName;
      String? indexKey;
      if (imageId != null && imageId.isNotEmpty) {
        indexKey = preferThumbnail ? '${imageId}_thumb' : imageId;
        final ext = extensionFromImageUrl(effectiveUrl);
        localFileName =
            preferThumbnail ? '${imageId}_thumb$ext' : '$imageId$ext';
      } else {
        localFileName = p.basename(Uri.parse(effectiveUrl).path);
        if (localFileName.isEmpty) {
          HalideDebugLog.log(
            'Sync',
            'cannot derive local filename (empty basename) roll=$rollId url=$effectiveUrl',
          );
          return imageUrl;
        }
      }

      final localPath = p.join(localDir.path, localFileName);
      final file = File(localPath);

      if (await file.exists()) {
        if (await isPlausibleImageCacheFile(file)) {
          if (indexKey != null) {
            await LocalImagePathIndex.instance.put(
              rollId,
              indexKey,
              p.relative(localPath, from: docDir.path),
            );
          }
          HalideDebugLog.log(
            'Sync',
            'cache hit (reuse file) roll=$rollId imageId=${imageId ?? "—"} '
            'thumb=$preferThumbnail path=$localPath',
          );
          return localPath;
        }
        try {
          await file.delete();
        } catch (_) {}
        HalideDebugLog.log(
          'Sync',
          'removed corrupt/short cache file, re-downloading: $localFileName roll=$rollId',
        );
      }

      pendingDownloadPath = localPath;
      HalideDebugLog.log(
        'Sync',
        'GET roll=$rollId imageId=${imageId ?? "—"} thumb=$preferThumbnail → $effectiveUrl',
      );
      final response = await _dio.download(
        effectiveUrl,
        localPath,
        options: _downloadOptions,
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 400) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
        HalideDebugLog.log(
          'Sync',
          'HTTP error roll=$rollId status=$code url=$effectiveUrl '
          '(response not saved or deleted)',
        );
        return imageUrl;
      }
      if (!await isPlausibleImageCacheFile(file)) {
        final detail = await _describeNonImageFile(file);
        try {
          await file.delete();
        } catch (_) {}
        HalideDebugLog.log(
          'Sync',
          'response is not JPEG/PNG (wrong content-type or HTML error page?) '
          'roll=$rollId url=$effectiveUrl $detail',
        );
        return imageUrl;
      }

      if (indexKey != null) {
        await LocalImagePathIndex.instance.put(
          rollId,
          indexKey,
          p.relative(localPath, from: docDir.path),
        );
      }

      final bytes = await file.length();
      HalideDebugLog.log(
        'Sync',
        'saved roll=$rollId imageId=${imageId ?? "—"} bytes=$bytes path=$localPath',
      );
      return localPath;
    } on DioException catch (e) {
      final path = pendingDownloadPath;
      if (path != null) {
        try {
          final f = File(path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      HalideDebugLog.log(
        'Sync',
        'network/download failed roll=$rollId imageId=${imageId ?? "—"} '
        '${_formatDioException(e)} url=$effectiveUrl',
      );
      return imageUrl;
    } catch (e, st) {
      final short =
          st.toString().length > 400 ? '${st.toString().substring(0, 400)}…' : st.toString();
      HalideDebugLog.log(
        'Sync',
        'unexpected error roll=$rollId url=$effectiveUrl: $e\n$short',
      );
      return imageUrl;
    }
  }

  /// Prefetches full-resolution files in bounded parallel batches.
  Future<void> syncRollParallel(
    String rollId,
    List<String> imageUrls, {
    List<String>? imageIds,
    int concurrency = 6,
  }) async {
    final urls = imageUrls.where((u) => u.trim().isNotEmpty).toList();
    if (imageIds != null && imageIds.length != urls.length) {
      HalideDebugLog.log(
        'Sync',
        'imageIds length ${imageIds.length} != urls ${urls.length}; ignoring ids',
      );
    }
    final ids = imageIds != null && imageIds.length == urls.length ? imageIds : null;

    for (var i = 0; i < urls.length; i += concurrency) {
      final end = i + concurrency > urls.length ? urls.length : i + concurrency;
      final futures = <Future<String>>[];
      for (var j = i; j < end; j++) {
        final id = ids != null ? ids[j] : null;
        futures.add(ensureLocalSync(rollId, urls[j], imageId: id));
      }
      await Future.wait(futures);
    }
  }

  /// Prefetches thumbnail objects (when URLs follow `*_thumb.jpg` convention).
  Future<void> prefetchThumbnailsParallel(
    String rollId,
    List<String> fullImageUrls, {
    List<String>? imageIds,
    int concurrency = 8,
  }) async {
    final entries = <({String fullUrl, String? id})>[];
    for (var i = 0; i < fullImageUrls.length; i++) {
      final u = fullImageUrls[i];
      final t = thumbUrlForFullImageUrl(u);
      if (t == u) continue;
      final id = imageIds != null && i < imageIds.length ? imageIds[i] : null;
      entries.add((fullUrl: u, id: id));
    }
    for (var i = 0; i < entries.length; i += concurrency) {
      final end = i + concurrency > entries.length ? entries.length : i + concurrency;
      final batch = entries.sublist(i, end);
      await Future.wait(
        batch.map(
          (e) => ensureLocalSync(
            rollId,
            e.fullUrl,
            imageId: e.id,
            preferThumbnail: true,
          ),
        ),
      );
    }
  }

  /// Sequential prefetch (legacy).
  Future<void> syncRoll(
    String rollId,
    List<String> imageUrls, {
    List<String>? imageIds,
  }) async {
    await syncRollParallel(
      rollId,
      imageUrls,
      imageIds: imageIds,
      concurrency: 1,
    );
  }
}
