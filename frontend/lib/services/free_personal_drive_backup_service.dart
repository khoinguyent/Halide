import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/roll.dart';
import 'google_drive_device_client.dart';
import 'local_image_path_index.dart';

/// Outcome of backing up one roll from on-device lab frames to Agxel Vault.
class FreePersonalDriveRollBackupResult {
  final String rollId;
  final int uploaded;
  final int skipped;
  final int failed;
  final List<String> errors;
  final String? error;
  final bool needsReauth;

  const FreePersonalDriveRollBackupResult({
    required this.rollId,
    this.uploaded = 0,
    this.skipped = 0,
    this.failed = 0,
    this.errors = const [],
    this.error,
    this.needsReauth = false,
  });

  bool get isRollLevelError => (error ?? '').trim().isNotEmpty || (failed > 0 && uploaded == 0);
}

/// Free tier: push local `lab:*` frames straight to the user's personal Drive
/// (Agxel Vault / {roll title}/), without Halide R2.
class FreePersonalDriveBackupService {
  Future<FreePersonalDriveRollBackupResult> backupRoll({
    required Roll roll,
    required GoogleDriveDeviceClient drive,
    String? vaultFolderId,
    void Function(int done, int total)? onFrameProgress,
  }) async {
    final rollId = roll.id;
    try {
      final entries = await LocalImagePathIndex.instance.listLabEntriesSorted(rollId);
      if (entries.isEmpty) {
        return FreePersonalDriveRollBackupResult(
          rollId: rollId,
          error:
              'No local scans on this device. Sync the Drive folder/ZIP first, then back up.',
        );
      }

      final vaultId = vaultFolderId ?? await drive.ensureVaultFolder();
      final folderName = GoogleDriveDeviceClient.sanitizeFolderName(
        (roll.title?.trim().isNotEmpty ?? false) ? roll.title : roll.name,
      );
      final rollFolderId = await drive.findOrCreateFolder(
        name: folderName,
        parentId: vaultId,
      );

      final readme = _buildReadme(roll);
      await drive.uploadOrUpdateFile(
        parentId: rollFolderId,
        name: 'README.txt',
        bytes: Uint8List.fromList(utf8.encode(readme)),
        mimeType: 'text/plain',
      );

      final docs = await getApplicationDocumentsDirectory();
      var uploaded = 0;
      var failed = 0;
      final errors = <String>[];
      final total = entries.length;
      onFrameProgress?.call(0, total);

      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final frameIndex = entry.$1;
        final rel = entry.$3;
        final abs = p.isAbsolute(rel) ? rel : p.join(docs.path, rel);
        final file = File(abs);
        if (!await file.exists()) {
          failed++;
          errors.add('Missing local file for frame $frameIndex');
          onFrameProgress?.call(i + 1, total);
          continue;
        }
        Uint8List bytes;
        try {
          bytes = await file.readAsBytes();
        } catch (e) {
          failed++;
          errors.add('Could not read frame $frameIndex: $e');
          onFrameProgress?.call(i + 1, total);
          continue;
        }
        if (bytes.isEmpty) {
          failed++;
          errors.add('Empty file for frame $frameIndex');
          onFrameProgress?.call(i + 1, total);
          continue;
        }

        final name = '${(frameIndex + 1).toString().padLeft(3, '0')}.jpg';
        try {
          await drive.uploadOrUpdateFile(
            parentId: rollFolderId,
            name: name,
            bytes: bytes,
            mimeType: 'image/jpeg',
          );
          uploaded++;
        } on GoogleDriveDeviceException catch (e) {
          if (e.needsReauth) rethrow;
          failed++;
          errors.add('Frame $frameIndex: ${e.message}');
          debugPrint('[FreeDriveBackup] upload failed roll=$rollId frame=$frameIndex: $e');
        } catch (e) {
          failed++;
          errors.add('Frame $frameIndex: $e');
          debugPrint('[FreeDriveBackup] upload failed roll=$rollId frame=$frameIndex: $e');
        }
        onFrameProgress?.call(i + 1, total);
      }

      if (uploaded == 0 && failed > 0) {
        return FreePersonalDriveRollBackupResult(
          rollId: rollId,
          uploaded: uploaded,
          failed: failed,
          errors: errors,
          error: errors.isNotEmpty ? errors.first : 'Backup failed',
        );
      }

      return FreePersonalDriveRollBackupResult(
        rollId: rollId,
        uploaded: uploaded,
        failed: failed,
        errors: errors,
        error: failed > 0 && uploaded == 0
            ? (errors.isNotEmpty ? errors.first : 'Backup failed')
            : null,
      );
    } on GoogleDriveDeviceException catch (e) {
      return FreePersonalDriveRollBackupResult(
        rollId: rollId,
        error: e.message,
        needsReauth: e.needsReauth,
      );
    } catch (e) {
      return FreePersonalDriveRollBackupResult(
        rollId: rollId,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  static String _buildReadme(Roll roll) {
    final title =
        (roll.title?.trim().isNotEmpty ?? false) ? roll.title!.trim() : 'Untitled Roll';
    final description =
        (roll.description?.trim().isNotEmpty ?? false) ? roll.description!.trim() : '(none)';
    final film = '${roll.brand} ${roll.name}'.trim();
    final iso = roll.shotAtIso != null ? 'shot at ${roll.shotAtIso}' : '(unknown)';
    return [
      'Agxel Vault — Roll Archive',
      '',
      'Title: $title',
      'Description: $description',
      'Film: $film',
      'ISO: $iso',
      'Roll ID: ${roll.id}',
      '',
    ].join('\n');
  }
}
