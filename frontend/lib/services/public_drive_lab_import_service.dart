import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'image_cache_utils.dart';
import 'local_image_path_index.dart';

/// Downloads a **public** Google Drive file or ZIP on-device, extracts images,
/// and registers them under [LocalImagePathIndex] keys `lab:0` … `lab:n-1`.
///
/// Folder URLs are not supported here (use Google-connected cloud sync).
class PublicDriveLabImportService {
  PublicDriveLabImportService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 300),
      followRedirects: true,
      maxRedirects: 12,
      validateStatus: (s) => s != null && s >= 200 && s < 400,
      headers: const {'User-Agent': 'HalideFilm/1.0 (Flutter; iOS/Android)'},
    ),
  );

  static final _downloadOptions = Options(responseType: ResponseType.bytes);

  /// True when the string looks like a Drive **folder** link (needs OAuth / server flow).
  static bool isDriveFolderUrl(String raw) {
    return raw.toLowerCase().contains('/folders/');
  }

  /// Extract Drive file/folder id from a share URL or return a bare id.
  static String extractDriveId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(raw, 'driveUrlOrId', 'required');
    }
    if (RegExp(r'^[a-zA-Z0-9_-]{10,}$').hasMatch(value)) {
      return value;
    }
    var m = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(value);
    if (m != null) return m.group(1)!;
    m = RegExp(r'/folders/([a-zA-Z0-9_-]+)').firstMatch(value);
    if (m != null) return m.group(1)!;
    m = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(value);
    if (m != null) return m.group(1)!;
    throw FormatException('Could not extract Google Drive id from: $raw');
  }

  /// Import images for [rollId]. Returns number of frames saved.
  /// Throws if download fails or no image bytes could be saved.
  static Future<int> importPublicFileOrZipToLocal({
    required String rollId,
    required String driveUrlOrId,
  }) async {
    if (isDriveFolderUrl(driveUrlOrId)) {
      throw UnsupportedError('Folder links require Google Drive sign-in. Use cloud sync for folders.');
    }
    final id = extractDriveId(driveUrlOrId);
    final bytes = await _downloadDrivePublicBytes(id);
    return _persistLabBytes(rollId, bytes);
  }

  static Future<Uint8List> _downloadDrivePublicBytes(String fileId) async {
    final base = 'https://drive.google.com/uc?export=download&id=$fileId';
    Future<Uint8List> getBytes(String url) async {
      final resp = await _dio.get<List<int>>(url, options: _downloadOptions);
      final list = resp.data;
      if (list == null) return Uint8List(0);
      return Uint8List.fromList(list);
    }

    var data = await getBytes(base);
    if (_isZipBytes(data)) return data;

    final preview = String.fromCharCodes(data.take(4096));
    final confirm = RegExp(r'confirm=([0-9A-Za-z_]+)').firstMatch(preview)?.group(1) ??
        RegExp(r'''confirm_token["']?\s*[:=]\s*["']([0-9A-Za-z_]+)''', caseSensitive: false)
            .firstMatch(preview)
            ?.group(1);
    if (confirm != null) {
      final u =
          'https://drive.google.com/uc?export=download&confirm=$confirm&id=$fileId';
      data = await getBytes(u);
    }
    return data;
  }

  static bool _isZipBytes(Uint8List data) {
    return data.length >= 4 && data[0] == 0x50 && data[1] == 0x4b && data[2] == 0x03 && data[3] == 0x04;
  }

  static bool _isJpeg(Uint8List b) => b.length >= 2 && b[0] == 0xff && b[1] == 0xd8;

  static bool _isPng(Uint8List b) =>
      b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4e &&
      b[3] == 0x47 &&
      b[4] == 0x0d &&
      b[5] == 0x0a &&
      b[6] == 0x1a &&
      b[7] == 0x0a;

  static bool _safeZipMember(String name) {
    if (name.contains('..')) return false;
    final n = name.replaceAll('\\', '/');
    if (n.startsWith('/') || n.startsWith('//')) return false;
    return true;
  }

  static Future<int> _persistLabBytes(String rollId, Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw StateError('Empty download from Google Drive.');
    }
    final htmlHead = String.fromCharCodes(bytes.take(64)).toLowerCase();
    if (htmlHead.contains('<!doctype') || htmlHead.contains('<html')) {
      throw StateError('Google Drive returned a web page instead of a file (link may not be public).');
    }

    await LocalImagePathIndex.instance.removeKeysWithPrefix(rollId, 'lab:');
    final docDir = await getApplicationDocumentsDirectory();
    final destDir = Directory(p.join(docDir.path, 'lab_import', rollId));
    if (await destDir.exists()) {
      await destDir.delete(recursive: true);
    }
    await destDir.create(recursive: true);

    final images = <({String sortKey, Uint8List jpegBytes})>[];

    if (_isZipBytes(bytes)) {
      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes, verify: false);
      } catch (e) {
        throw StateError('Could not read ZIP from Google Drive: $e');
      }
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final name = file.name;
        if (!_safeZipMember(name)) continue;
        final lower = name.toLowerCase();
        if (!(lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.png') ||
            lower.endsWith('.webp'))) {
          continue;
        }
        final bytes = file.content;
        if (bytes.isEmpty) continue;
        final raw = Uint8List.fromList(bytes);
        final jpeg = await _toJpegBytes(raw, name);
        if (jpeg == null) continue;
        images.add((sortKey: name.toLowerCase(), jpegBytes: jpeg));
      }
      images.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    } else {
      final jpeg = await _toJpegBytes(bytes, 'scan.jpg');
      if (jpeg == null) {
        throw StateError('Download is not a ZIP and not a supported image.');
      }
      images.add((sortKey: '0', jpegBytes: jpeg));
    }

    if (images.isEmpty) {
      throw StateError('No images found in this Drive file.');
    }

    var frame = 0;
    for (var i = 0; i < images.length; i++) {
      final name = 'frame_${frame.toString().padLeft(4, '0')}.jpg';
      final rel = p.join('lab_import', rollId, name);
      final abs = p.join(docDir.path, rel);
      final f = File(abs);
      await f.writeAsBytes(images[i].jpegBytes, flush: true);
      if (!await isPlausibleImageCacheFile(f)) {
        try {
          await f.delete();
        } catch (_) {}
        continue;
      }
      await LocalImagePathIndex.instance.put(rollId, 'lab:$frame', rel);
      frame++;
    }

    final count = frame;
    if (count == 0) {
      throw StateError('Downloaded data could not be saved as valid image files.');
    }
    debugPrint('[LabImport] roll=$rollId saved $count frames under lab_import/');
    return count;
  }

  /// One raw blob per Drive file (JPEG/PNG/WebP), saved as [lab:N] like ZIP import. No network.
  static Future<int> persistSeparateImageBlobsAsLabFrames({
    required String rollId,
    required List<Uint8List> rawBlobsInOrder,
  }) async {
    if (rawBlobsInOrder.isEmpty) {
      throw StateError('No image data to save.');
    }

    await LocalImagePathIndex.instance.removeKeysWithPrefix(rollId, 'lab:');
    final docDir = await getApplicationDocumentsDirectory();
    final destDir = Directory(p.join(docDir.path, 'lab_import', rollId));
    if (await destDir.exists()) {
      await destDir.delete(recursive: true);
    }
    await destDir.create(recursive: true);

    var frame = 0;
    for (var i = 0; i < rawBlobsInOrder.length; i++) {
      final hint = 'frame_$i.jpg';
      final jpeg = await _toJpegBytes(rawBlobsInOrder[i], hint);
      if (jpeg == null) continue;
      final name = 'frame_${frame.toString().padLeft(4, '0')}.jpg';
      final rel = p.join('lab_import', rollId, name);
      final abs = p.join(docDir.path, rel);
      final f = File(abs);
      await f.writeAsBytes(jpeg, flush: true);
      if (!await isPlausibleImageCacheFile(f)) {
        try {
          await f.delete();
        } catch (_) {}
        continue;
      }
      await LocalImagePathIndex.instance.put(rollId, 'lab:$frame', rel);
      frame++;
    }

    if (frame == 0) {
      throw StateError('Downloaded files could not be saved as valid images.');
    }
    debugPrint('[LabImport] roll=$rollId saved $frame frames (authenticated folder)');
    return frame;
  }

  static Future<Uint8List?> _toJpegBytes(Uint8List raw, String hintName) async {
    if (_isJpeg(raw)) return raw;
    if (_isPng(raw)) {
      try {
        final decoded = img.decodePng(raw);
        if (decoded == null) return null;
        final j = img.encodeJpg(decoded, quality: 90);
        return Uint8List.fromList(j);
      } catch (_) {
        return null;
      }
    }
    final lower = hintName.toLowerCase();
    if (lower.endsWith('.webp')) {
      try {
        final decoded = img.decodeImage(raw);
        if (decoded == null) return null;
        final j = img.encodeJpg(decoded, quality: 90);
        return Uint8List.fromList(j);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
