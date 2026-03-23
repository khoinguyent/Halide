import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

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
      // Store in a structured way: scans/<roll_id>/<filename>
      final fileName = p.basename(Uri.parse(imageUrl).path);
      if (fileName.isEmpty) return imageUrl;

      final localDir = Directory(p.join(docDir.path, 'scans', rollId));
      if (!await localDir.exists()) {
        await localDir.create(recursive: true);
      }

      final localPath = p.join(localDir.path, fileName);
      final file = File(localPath);

      if (await file.exists()) {
        return localPath;
      }

      // Download the image
      debugPrint('[LocalSync] Downloading $imageUrl to $localPath');
      await _dio.download(imageUrl, localPath);
      
      return localPath;
    } catch (e) {
      debugPrint('[LocalSync] Failed to sync $imageUrl: $e');
      return imageUrl;
    }
  }

  /// Prefetches all images in a roll for offline access.
  Future<void> syncRoll(String rollId, List<String> imageUrls) async {
    for (final url in imageUrls) {
      await ensureLocalSync(rollId, url);
    }
  }
}
