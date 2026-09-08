import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'public_drive_lab_import_service.dart';

/// Free tier: folder sync downloads each image from the API (Google Drive proxy)
/// to local storage. No R2 / no Image rows.
///
/// Uses bounded parallel downloads + retries so large lab folders finish faster
/// and survive transient network blips.
class AuthenticatedDriveFolderImportService {
  AuthenticatedDriveFolderImportService._();

  static const _maxConcurrent = 3;
  static const _maxAttempts = 3;

  static Future<int> importFolder({
    required ApiService api,
    required String rollId,
    required String folderUrl,
    void Function(int done, int total)? onProgress,
  }) async {
    final resp = await api.post(
      '/api/v1/storage/gdrive/free_folder_manifest',
      data: {
        'roll_id': rollId,
        'folder_url_or_id': folderUrl,
      },
    );
    final data = resp.data;
    if (data is! Map) {
      throw StateError('Unexpected manifest response');
    }
    final rawIds = data['file_ids'];
    if (rawIds is! List) {
      throw StateError('Manifest missing file_ids');
    }
    final fileIds = rawIds.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    if (fileIds.isEmpty) {
      throw StateError('No images found in this Drive folder.');
    }

    final total = fileIds.length;
    final slots = List<Uint8List?>.filled(total, null);
    final errors = List<String?>.filled(total, null);
    var completed = 0;

    Future<void> downloadOne(int index) async {
      final id = fileIds[index];
      Object? lastError;
      for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
        try {
          final bytes = await api.getBytes(
            '/api/v1/storage/gdrive/free_file/${Uri.encodeComponent(id)}',
            receiveTimeout: const Duration(minutes: 5),
          );
          if (bytes.isEmpty) {
            throw StateError('Empty download');
          }
          slots[index] = bytes;
          lastError = null;
          break;
        } catch (e) {
          lastError = e;
          debugPrint(
            '[FreeLabSync] download $id attempt $attempt/$_maxAttempts failed: $e',
          );
          if (attempt < _maxAttempts) {
            await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
          }
        }
      }
      if (slots[index] == null) {
        errors[index] = _friendlyDownloadError(lastError);
      }
      completed++;
      onProgress?.call(completed, total);
    }

    // Bounded parallelism.
    var next = 0;
    final workers = <Future<void>>[];
    for (var w = 0; w < _maxConcurrent; w++) {
      workers.add(() async {
        while (true) {
          final i = next++;
          if (i >= total) return;
          await downloadOne(i);
        }
      }());
    }
    await Future.wait(workers);

    final blobs = <Uint8List>[];
    final failed = <String>[];
    for (var i = 0; i < total; i++) {
      final b = slots[i];
      if (b != null) {
        blobs.add(b);
      } else {
        failed.add(errors[i] ?? 'file ${fileIds[i]}');
      }
    }

    if (blobs.isEmpty) {
      throw StateError(
        failed.isEmpty
            ? 'No images downloaded from this Drive folder.'
            : 'All downloads failed. ${failed.first}',
      );
    }

    final saved = await PublicDriveLabImportService.persistSeparateImageBlobsAsLabFrames(
      rollId: rollId,
      rawBlobsInOrder: blobs,
    );

    if (failed.isNotEmpty) {
      debugPrint(
        '[FreeLabSync] roll=$rollId saved=$saved skipped_failed=${failed.length}',
      );
    }
    return saved;
  }

  static String _friendlyDownloadError(Object? e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Timed out downloading a scan. Keep the app open and retry.';
        case DioExceptionType.connectionError:
          return 'Network interrupted while downloading. Keep the app open and retry.';
        default:
          final detail = e.response?.data;
          if (detail is Map && detail['detail'] != null) {
            return detail['detail'].toString();
          }
          return e.message ?? 'Download failed (${e.type.name})';
      }
    }
    return e?.toString() ?? 'Download failed';
  }
}
