import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/roll_gallery.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/dashboard_provider.dart';
import 'package:frontend/providers/roll_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/gdrive_connection_guard.dart';
import 'package:frontend/services/local_sync_service.dart';
import 'package:frontend/services/public_drive_lab_import_service.dart';
import 'package:frontend/services/authenticated_drive_folder_import_service.dart';
import 'package:frontend/core/providers/notification_provider.dart';
import 'package:frontend/core/models/notification_model.dart';
import 'package:frontend/models/user_profile.dart';

class FetchScansHelper {
  static Future<void> handleFetchScans({
    required BuildContext context,
    required WidgetRef ref,
    required String rollId,
    required String driveUrl,
    Function(bool isFetching)? onFetchingStateChanged,
  }) async {
    debugPrint('Fetching from $driveUrl');
    if (!context.mounted) return;

    final _api = ApiService();
    final trimmed = driveUrl.trim();

    if (!PublicDriveLabImportService.isDriveFolderUrl(trimmed)) {
      onFetchingStateChanged?.call(true);
      try {
        final count = await PublicDriveLabImportService.importPublicFileOrZipToLocal(
          rollId: rollId,
          driveUrlOrId: trimmed,
        );
        if (count > 0) {
          final user = ref.read(userProvider);
          final token = await user?.getIdToken();
          if (token != null) {
            try {
              await ref.read(rollServiceProvider).updateRollStatus(token, rollId, 'scanned');
            } catch (e) {
              debugPrint('[FetchScansHelper] mark scanned: $e');
            }
          }
          ref.invalidate(rollDetailProvider(rollId));
          ref.invalidate(rollGalleryPairsProvider(rollId));
          ref.invalidate(rollHasLocalLabScansProvider(rollId));
          ref.invalidate(dashboardRollsProvider);
          if (context.mounted) {
            ref.read(notificationProvider.notifier).show(
                  'SAVED $count PHOTO(S) ON THIS DEVICE.',
                  type: NotificationType.success,
                );
          }
          return;
        }
      } catch (e) {
        debugPrint('[FetchScansHelper] local lab import failed, will try cloud: $e');
      } finally {
        if (context.mounted) onFetchingStateChanged?.call(false);
      }
    }

    final gdriveOk = await ensureGoogleDriveConnected(context, ref);
    if (!gdriveOk) return;

    if (PublicDriveLabImportService.isDriveFolderUrl(trimmed) &&
        ref.read(userPlanProvider) == UserPlan.free) {
      onFetchingStateChanged?.call(true);
      try {
        final count = await AuthenticatedDriveFolderImportService.importFolder(
          api: _api,
          rollId: rollId,
          folderUrl: trimmed,
        );
        if (count > 0) {
          final user = ref.read(userProvider);
          final token = await user?.getIdToken();
          if (token != null) {
            try {
              await ref.read(rollServiceProvider).updateRollStatus(token, rollId, 'scanned');
            } catch (e) {
              debugPrint('[FetchScansHelper] mark scanned: $e');
            }
          }
          ref.invalidate(rollDetailProvider(rollId));
          ref.invalidate(rollGalleryPairsProvider(rollId));
          ref.invalidate(rollHasLocalLabScansProvider(rollId));
          ref.invalidate(dashboardRollsProvider);
          if (context.mounted) {
            ref.read(notificationProvider.notifier).show(
                  'SAVED $count PHOTO(S) ON THIS DEVICE.',
                  type: NotificationType.success,
                );
          }
        }
      } catch (e) {
        debugPrint('[FetchScansHelper] free folder import failed: $e');
        if (context.mounted) {
          ref.read(notificationProvider.notifier).show(
                'COULDN\'T DOWNLOAD FOLDER. CHECK DRIVE ACCESS AND TRY AGAIN.',
                type: NotificationType.error,
              );
        }
      } finally {
        if (context.mounted) onFetchingStateChanged?.call(false);
      }
      return;
    }

    onFetchingStateChanged?.call(true);
    try {
      final resp = await _api.post(
        '/api/v1/storage/gdrive/sync_images_from_url',
        data: {
          'roll_id': rollId,
          'gdrive_url_or_id': driveUrl,
        },
      );
      final detail = resp.data is Map ? resp.data['detail']?.toString() : null;
      if (detail != null && detail.toLowerCase().contains('background')) {
        debugPrint(
          '[FetchScansHelper] Drive folder sync runs on the server; thumbnails appear after ingest finishes (pull to refresh or wait ~5–30s).',
        );
      }

      if (!context.mounted) return;
      ref.invalidate(dashboardRollsProvider);
      ref.invalidate(rollDetailProvider(rollId));
      ref.invalidate(rollGalleryPairsProvider(rollId));
      ref.invalidate(rollHasLocalLabScansProvider(rollId));

      try {
        final roll = await ref.read(rollDetailProvider(rollId).future);
        final triple = await RollGalleryPairs.tripleAsync(roll);
        final urls = <String>[];
        final ids = <String>[];
        for (var i = 0; i < triple.$1.length; i++) {
          if (triple.$1[i].startsWith('http')) {
            urls.add(triple.$1[i]);
            ids.add(triple.$2[i]);
          }
        }
        if (urls.isNotEmpty) {
          await LocalSyncService().syncRollParallel(roll.id, urls, imageIds: ids);
        }
      } catch (e) {
        debugPrint('[FetchScansHelper] prefetch after Drive sync: $e');
      }

      if (context.mounted) {
        ref.invalidate(dashboardRollsProvider);
        ref.invalidate(rollDetailProvider(rollId));
      }

      // No snackbar for background sync as per user request
    } on DioException catch (e) {
      if (!context.mounted) return;
      final data = e.response?.data;
      final detail = data is Map && data['detail'] != null ? data['detail'].toString() : null;
      debugPrint('[FetchScansHelper] Fetch failed: status=${e.response?.statusCode} detail=$detail data=$data');
      ref.read(notificationProvider.notifier).show(
        'COULDN\'T RETRIEVE PHOTOS. PLEASE CHECK YOUR DRIVE LINK.',
        type: NotificationType.error,
      );
    } catch (e) {
      if (!context.mounted) return;
      ref.read(notificationProvider.notifier).show(
        'SOMETHING WENT WRONG WHILE FETCHING PHOTOS.',
        type: NotificationType.error,
      );
    } finally {
      if (context.mounted) onFetchingStateChanged?.call(false);
    }
  }
}
