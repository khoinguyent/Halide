import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';

import 'api_service.dart';
import 'public_drive_lab_import_service.dart';

/// Free tier: download a Drive ZIP (or single image file) via authenticated
/// `free_file` proxy, then persist frames on-device. No R2 / no Image rows.
class AuthenticatedDriveZipImportService {
  AuthenticatedDriveZipImportService._();

  static Future<int> importZipOrFile({
    required ApiService api,
    required String rollId,
    required String driveUrlOrId,
  }) async {
    final fileId = PublicDriveLabImportService.extractDriveId(driveUrlOrId);
    final Uint8List bytes;
    try {
      bytes = await api.getBytes(
        '/api/v1/storage/gdrive/free_file/${Uri.encodeComponent(fileId)}',
      );
    } on DioException catch (e) {
      final detail = e.response?.data;
      final msg = detail is Map ? detail['detail']?.toString() : e.message;
      throw StateError('Could not download Drive file: ${msg ?? e}');
    }

    if (bytes.isEmpty) {
      throw StateError('Empty download from Google Drive.');
    }

    final head = String.fromCharCodes(bytes.take(64)).toLowerCase();
    if (head.contains('<!doctype') || head.contains('<html')) {
      throw StateError(
        'Google Drive returned a web page instead of a file. '
        'Reconnect Drive and ensure you can open the link in a browser.',
      );
    }

    // ZIP → extract images; otherwise treat as a single image blob.
    if (_isZip(bytes)) {
      final blobs = <Uint8List>[];
      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes, verify: false);
      } catch (e) {
        throw StateError('Could not read ZIP from Google Drive: $e');
      }
      final members = archive.files.where((f) => f.isFile).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (final file in members) {
        final name = file.name.replaceAll('\\', '/');
        if (name.contains('..') || name.startsWith('/')) continue;
        final lower = name.toLowerCase();
        if (!(lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.png') ||
            lower.endsWith('.webp'))) {
          continue;
        }
        final content = file.content;
        if (content.isEmpty) continue;
        blobs.add(Uint8List.fromList(content));
      }
      if (blobs.isEmpty) {
        throw StateError('No images found in this Drive ZIP.');
      }
      return PublicDriveLabImportService.persistSeparateImageBlobsAsLabFrames(
        rollId: rollId,
        rawBlobsInOrder: blobs,
      );
    }

    return PublicDriveLabImportService.persistSeparateImageBlobsAsLabFrames(
      rollId: rollId,
      rawBlobsInOrder: [bytes],
    );
  }

  static bool _isZip(Uint8List data) {
    return data.length >= 4 &&
        data[0] == 0x50 &&
        data[1] == 0x4b &&
        data[2] == 0x03 &&
        data[3] == 0x04;
  }
}
