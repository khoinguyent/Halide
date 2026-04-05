import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import 'local_sync_service.dart';

/// Rotates a roll scan 90° clockwise, saves locally, and optionally replaces the cloud object (Pro).
class RollImageEditService {
  RollImageEditService({LocalSyncService? localSync}) : _local = localSync ?? LocalSyncService();

  final LocalSyncService _local;

  /// [quarterTurns]: 1 = 90° CW, -1 = 90° CCW, 2 = 180°, etc.
  ///
  /// Output path matches [LocalSyncService.ensureLocalSync] / [resolveLocalPath] so the viewer
  /// reloads the same file (indexed by [imageId] when set).
  Future<String> rotateQuarterTurnsAndSaveLocal({
    required String rollId,
    required String imageUrl,
    int quarterTurns = 1,
    String? imageId,
  }) async {
    final bytes = await _loadImageBytes(rollId, imageUrl, imageId: imageId);
    final decoded = _decodeRaster(bytes);
    if (decoded == null) {
      throw StateError(
        'Could not decode image (unsupported or corrupt file). Try JPEG or PNG.',
      );
    }
    final rotated = img.copyRotate(decoded, angle: quarterTurns * 90.0);
    final outBytes = img.encodeJpg(rotated, quality: 92);

    final docDir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(docDir.path, 'scans', rollId));
    if (!await outDir.exists()) await outDir.create(recursive: true);

    late final String localFileName;
    if (imageId != null && imageId.isNotEmpty) {
      final ext = extensionFromImageUrl(imageUrl);
      localFileName = '$imageId$ext';
    } else {
      var base = p.basename(Uri.parse(imageUrl).path);
      if (base.isEmpty) {
        base = 'frame_${rollId}_${imageUrl.hashCode.abs()}.jpg';
      }
      localFileName = base;
    }
    final outPath = p.join(outDir.path, localFileName);
    await File(outPath).writeAsBytes(outBytes, flush: true);
    return outPath;
  }

  /// 90° clockwise (same as one quarter-turn).
  Future<String> rotate90ClockwiseAndSaveLocal({
    required String rollId,
    required String imageUrl,
    String? imageId,
  }) =>
      rotateQuarterTurnsAndSaveLocal(
        rollId: rollId,
        imageUrl: imageUrl,
        quarterTurns: 1,
        imageId: imageId,
      );

  /// JPEG / PNG / GIF / WebP / BMP — not HEIC (decodeImage often suffices; explicit fallbacks for edge cases).
  img.Image? _decodeRaster(Uint8List bytes) {
    final a = img.decodeImage(bytes);
    if (a != null) return a;
    return img.decodeJpg(bytes) ??
        img.decodePng(bytes) ??
        img.decodeWebP(bytes);
  }

  Future<Uint8List> _loadImageBytes(
    String rollId,
    String imageUrl, {
    String? imageId,
  }) async {
    final synced = await _local.ensureLocalSync(rollId, imageUrl, imageId: imageId);
    if (synced.startsWith('http')) {
      final r = await http.get(Uri.parse(synced));
      if (r.statusCode != 200) {
        throw StateError('Failed to download image: ${r.statusCode}');
      }
      return r.bodyBytes;
    }
    final path = synced.startsWith('file://') ? Uri.parse(synced).toFilePath() : synced;
    return File(path).readAsBytes();
  }

  /// Pro: PUT rotated JPEG to API so the next fetch shows the edit on any device.
  Future<bool> replaceCloudImage({
    required String rollId,
    required String imageId,
    required File jpegFile,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (token == null || token.isEmpty) return false;

    final length = await jpegFile.length();
    const maxBytes = 15 * 1024 * 1024;
    if (length > maxBytes) return false;

    final uri = Uri.parse('${AppConfig.apiUrl}/rolls/$rollId/images/$imageId');
    final request = http.MultipartRequest('PUT', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        jpegFile.path,
        filename: p.basename(jpegFile.path),
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 200) {
      return true;
    }
    debugPrint('[RollImageEdit] replace cloud failed: ${resp.statusCode} ${resp.body}');
    return false;
  }
}
