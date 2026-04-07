import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api_service.dart';
import 'public_drive_lab_import_service.dart';

/// Free tier: folder sync downloads each image from the API (Google Drive proxy) to local storage.
/// No R2 and no server-side Image rows.
class AuthenticatedDriveFolderImportService {
  AuthenticatedDriveFolderImportService._();

  static Future<int> importFolder({
    required ApiService api,
    required String rollId,
    required String folderUrl,
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

    final blobs = <Uint8List>[];
    for (final id in fileIds) {
      try {
        final bytes = await api.getBytes(
          '/api/v1/storage/gdrive/free_file/${Uri.encodeComponent(id)}',
        );
        if (bytes.isNotEmpty) {
          blobs.add(bytes);
        }
      } on DioException catch (e) {
        throw StateError('Download failed for Drive file ($id): ${e.message}');
      }
    }

    return PublicDriveLabImportService.persistSeparateImageBlobsAsLabFrames(
      rollId: rollId,
      rawBlobsInOrder: blobs,
    );
  }
}
