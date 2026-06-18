import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../services/local_image_path_index.dart';

/// Local-first storage for gyro-scanned frames under Documents/HalideArchive/.
class GyroScanCacheService {
  GyroScanCacheService._();
  static final instance = GyroScanCacheService._();

  static const _archiveRoot = 'HalideArchive';

  Future<Directory> _framesDir(String rollId) async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(doc.path, _archiveRoot, 'rolls', 'roll_$rollId', 'frames'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _rawName(int frameNumber) =>
      'frame_${frameNumber.toString().padLeft(2, '0')}_raw.jpg';

  String _thumbName(int frameNumber) =>
      'frame_${frameNumber.toString().padLeft(2, '0')}_thumb.jpg';

  /// Saves captured raw bytes and generates a lightweight JPEG thumbnail.
  /// Returns `(rawAbsolutePath, thumbAbsolutePath)`.
  Future<({String rawPath, String thumbPath})> saveCapture({
    required String rollId,
    required int frameNumber,
    required Uint8List rawBytes,
  }) async {
    final dir = await _framesDir(rollId);
    final rawFile = File(p.join(dir.path, _rawName(frameNumber)));
    await rawFile.writeAsBytes(rawBytes, flush: true);

    final thumbFile = File(p.join(dir.path, _thumbName(frameNumber)));
    final thumbBytes = await _generateThumb(rawBytes);
    await thumbFile.writeAsBytes(thumbBytes, flush: true);

    final doc = await getApplicationDocumentsDirectory();
    final thumbRel = p.relative(thumbFile.path, from: doc.path);
    await LocalImagePathIndex.instance.put(rollId, 'gyro:$frameNumber', thumbRel);

    debugPrint('[GyroScan] saved frame $frameNumber roll=$rollId raw=${rawFile.path}');
    return (rawPath: rawFile.path, thumbPath: thumbFile.path);
  }

  Future<Uint8List> _generateThumb(Uint8List rawBytes) async {
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return rawBytes;
      final thumb = img.copyResize(decoded, width: 400);
      return Uint8List.fromList(img.encodeJpg(thumb, quality: 78));
    } catch (e) {
      debugPrint('[GyroScan] thumb generation failed: $e');
      return rawBytes;
    }
  }

  Future<void> deleteRawAfterSync(String rawPath) async {
    try {
      final f = File(rawPath);
      if (await f.exists()) {
        await f.delete();
        debugPrint('[GyroScan] deleted raw after sync: $rawPath');
      }
    } catch (e) {
      debugPrint('[GyroScan] could not delete raw: $e');
    }
  }

  /// Gyro-scan thumb entries sorted by frame number.
  Future<List<(int frameNumber, String thumbAbsolutePath)>> listLocalThumbs(String rollId) async {
    final doc = await getApplicationDocumentsDirectory();
    final entries = await LocalImagePathIndex.instance.listGyroEntriesSorted(rollId);
    final out = <(int, String)>[];
    for (final (n, _, rel) in entries) {
      if (rel.contains('_raw')) continue;
      final abs = p.isAbsolute(rel) ? rel : p.join(doc.path, rel);
      if (await File(abs).exists()) {
        out.add((n, abs));
      }
    }
    return out;
  }
}
