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
import 'package:frontend/core/l10n/l10n_extension.dart';
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

    // Free: device photos only — no Drive URL lab sync (personal Drive backup is separate).
    if (ref.read(userPlanProvider) == UserPlan.free) {
      ref.read(notificationProvider.notifier).show(
            context.l10n.driveLabSyncProOnly,
            type: NotificationType.info,
          );
      return;
    }

    final api = ApiService();
    final trimmed = driveUrl.trim();

    final gdriveOk = await ensureGoogleDriveConnected(context, ref);
    if (!gdriveOk) return;

    // Pro: existing cloud Drive → R2 sync.
    onFetchingStateChanged?.call(true);
    try {
      final resp = await api.post(
        '/api/v1/storage/gdrive/sync_images_from_url',
        data: {
          'roll_id': rollId,
          'gdrive_url_or_id': trimmed,
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
    } on DioException catch (e) {
      if (!context.mounted) return;
      final data = e.response?.data;
      final detail = data is Map && data['detail'] != null ? data['detail'].toString() : null;
      debugPrint('[FetchScansHelper] Fetch failed: status=${e.response?.statusCode} detail=$detail data=$data');
      ref.read(notificationProvider.notifier).show(
        context.l10n.couldNotRetrievePhotos,
        type: NotificationType.error,
      );
    } catch (e) {
      if (!context.mounted) return;
      ref.read(notificationProvider.notifier).show(
        context.l10n.fetchPhotosError,
        type: NotificationType.error,
      );
    } finally {
      if (context.mounted) onFetchingStateChanged?.call(false);
    }
  }
}
