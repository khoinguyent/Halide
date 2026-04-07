import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/roll.dart';
import '../models/roll_gallery.dart';
import '../models/roll_status.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/halide_dialog.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/roll_provider.dart';
import '../services/api_service.dart';
import 'synced_image.dart';
import 'status_selector.dart';
import 'exif_capture_modal.dart';
import '../services/gdrive_connection_guard.dart';
import '../services/local_sync_service.dart';
import '../services/public_drive_lab_import_service.dart';
import '../services/authenticated_drive_folder_import_service.dart';
import '../core/providers/notification_provider.dart';
import '../core/models/notification_model.dart';
import '../providers/guidance_pending_provider.dart';

/// Whether this roll’s card shows the link/sync control (top-right next to the date).
/// Keep in sync with [RollCard] layout — [HomeView] uses this to decide when Drive/sync coach marks apply.
bool rollShowsLinkSyncControl(Roll roll, WidgetRef ref) {
  final st = roll.status;
  final statusOk = st == RollStatus.lab ||
      st == RollStatus.scanned ||
      st == RollStatus.syncing;
  if (!statusOk) return false;
  if (roll.imageUrls.isNotEmpty) return false;
  final localAsync = ref.watch(rollHasLocalLabScansProvider(roll.id));
  final hasLocal = switch (localAsync) {
    AsyncData(:final value) => value,
    _ => false,
  };
  return !hasLocal;
}

class RollCard extends ConsumerStatefulWidget {
  final Roll roll;
  /// When set, enables Archive coach marks on the status badge.
  final GlobalKey? guidanceStatusKey;
  /// Link icon / cloud sync icon (top-right) for lab & scanned rolls without images.
  final GlobalKey? guidanceLinkSyncKey;
  /// Shooting roll: EXIF / manual shot log (camera icon).
  final GlobalKey? guidanceExifKey;
  /// Shooting roll: opens roll detail for Shot Log tab.
  final GlobalKey? guidanceViewLogsKey;

  const RollCard({
    Key? key,
    required this.roll,
    this.guidanceStatusKey,
    this.guidanceLinkSyncKey,
    this.guidanceExifKey,
    this.guidanceViewLogsKey,
  }) : super(key: key);

  @override
  ConsumerState<RollCard> createState() => _RollCardState();
}

class _RollCardState extends ConsumerState<RollCard> {
  final ApiService _api = ApiService();
  String? _fetchingRollId;

  Future<void> _handleFetchScans(String rollId, String driveUrl) async {
    debugPrint('Fetching from $driveUrl');
    if (!mounted) return;

    final trimmed = driveUrl.trim();
    if (!PublicDriveLabImportService.isDriveFolderUrl(trimmed)) {
      setState(() => _fetchingRollId = rollId);
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
              debugPrint('[RollCard] mark scanned: $e');
            }
          }
          ref.invalidate(rollDetailProvider(rollId));
          ref.invalidate(rollGalleryPairsProvider(rollId));
          ref.invalidate(rollHasLocalLabScansProvider(rollId));
          ref.invalidate(dashboardRollsProvider);
          if (mounted) {
            ref.read(notificationProvider.notifier).show(
                  'SAVED $count PHOTO(S) ON THIS DEVICE.',
                  type: NotificationType.success,
                );
          }
          return;
        }
      } catch (e) {
        debugPrint('[RollCard] local lab import failed, will try cloud: $e');
      } finally {
        if (mounted) setState(() => _fetchingRollId = null);
      }
    }

    final gdriveOk = await ensureGoogleDriveConnected(context, ref);
    if (!gdriveOk) return;

    if (PublicDriveLabImportService.isDriveFolderUrl(trimmed) &&
        ref.read(userPlanProvider) == UserPlan.free) {
      setState(() => _fetchingRollId = rollId);
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
              debugPrint('[RollCard] mark scanned: $e');
            }
          }
          ref.invalidate(rollDetailProvider(rollId));
          ref.invalidate(rollGalleryPairsProvider(rollId));
          ref.invalidate(rollHasLocalLabScansProvider(rollId));
          ref.invalidate(dashboardRollsProvider);
          if (mounted) {
            ref.read(notificationProvider.notifier).show(
                  'SAVED $count PHOTO(S) ON THIS DEVICE.',
                  type: NotificationType.success,
                );
          }
        }
      } catch (e) {
        debugPrint('[RollCard] free folder import failed: $e');
        if (mounted) {
          ref.read(notificationProvider.notifier).show(
                'COULDN\'T DOWNLOAD FOLDER. CHECK DRIVE ACCESS AND TRY AGAIN.',
                type: NotificationType.error,
              );
        }
      } finally {
        if (mounted) setState(() => _fetchingRollId = null);
      }
      return;
    }

    setState(() => _fetchingRollId = rollId);
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
          '[RollCard] Drive folder sync runs on the server; thumbnails appear after ingest finishes (pull to refresh or wait ~5–30s).',
        );
      }

      if (!mounted) return;
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
        debugPrint('[RollCard] prefetch after Drive sync: $e');
      }

      if (mounted) {
        ref.invalidate(dashboardRollsProvider);
        ref.invalidate(rollDetailProvider(rollId));
      }

      // No snackbar for background sync as per user request
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final detail = data is Map && data['detail'] != null ? data['detail'].toString() : null;
      debugPrint('[RollCard] Fetch failed: status=${e.response?.statusCode} detail=$detail data=$data');
      ref.read(notificationProvider.notifier).show(
        'COULDN\'T RETRIEVE PHOTOS. PLEASE CHECK YOUR DRIVE LINK.',
        type: NotificationType.error,
      );
    } catch (e) {
      if (!mounted) return;
      ref.read(notificationProvider.notifier).show(
        'SOMETHING WENT WRONG WHILE FETCHING PHOTOS.',
        type: NotificationType.error,
      );
    } finally {
      if (!mounted) return;
      setState(() => _fetchingRollId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roll = widget.roll;

    final showLinkFetchAction = rollShowsLinkSyncControl(roll, ref);
    ref.watch(userPlanProvider);

    final driveUrl = (roll.driveUrl ?? '').trim();
    final hasDriveUrl = driveUrl.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/roll/${roll.id}'),
      child: GlassPanel(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => context.push('/roll/${roll.id}'),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Status Badge (tappable quick action) and Timestamp
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      key: widget.guidanceStatusKey,
                      onTap: () => _showQuickStatusSheet(context, ref, roll),
                      child: _StatusBadge(status: roll.status),
                    ),
                    if (roll.createdAt != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDate(roll.createdAt!),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                          if (showLinkFetchAction) ...[
                            const SizedBox(width: 10),
                            GestureDetector(
                              key: widget.guidanceLinkSyncKey,
                              behavior: HitTestBehavior.opaque,
                              onTap: () async {
                                if (_fetchingRollId == roll.id) return;
                                if (hasDriveUrl) {
                                  await _handleFetchScans(roll.id, driveUrl);
                                } else {
                                  await _showUrlBottomSheet(
                                    context,
                                    roll,
                                    onSavedFetch: (url) => _handleFetchScans(
                                      roll.id,
                                      url,
                                    ),
                                  );
                                }
                              },
                              child: (_fetchingRollId == roll.id || roll.status == RollStatus.syncing)
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.blueAccent,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      hasDriveUrl
                                          ? Icons.cloud_download
                                          : Icons.link_outlined,
                                      size: 20,
                                      color: hasDriveUrl
                                          ? Colors.blueAccent
                                          : Colors.white.withOpacity(0.55),
                                    ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),

              // Main Title & Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (roll.title?.trim().isNotEmpty ?? false)
                          ? roll.title!.trim()
                          : roll.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${roll.name} - ${roll.cameraName ?? "Unknown Camera"}${roll.lensName != null && roll.lensName!.trim().isNotEmpty ? " + ${roll.lensName!.trim()}" : ""}',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white.withOpacity(0.72),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (roll.description?.trim().isNotEmpty ?? false)
                          ? roll.description!.trim()
                          : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // State-specific content
              _buildStateContent(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannedOrSyncingContent(Roll roll) {
    final async = ref.watch(rollGalleryPairsProvider(roll.id));
    return async.when(
      loading: () => _ScannedContent(
        rollId: roll.id,
        imageUrls: const [],
        imageIds: const [],
        actualFrames: 0,
        totalFrames: roll.maxFrames,
      ),
      error: (_, __) => _ScannedContent(
        rollId: roll.id,
        imageUrls: const [],
        imageIds: const [],
        actualFrames: 0,
        totalFrames: roll.maxFrames,
      ),
      data: (triple) => _ScannedContent(
        rollId: roll.id,
        imageUrls: triple.$1,
        imageIds: triple.$2,
        actualFrames: triple.$1.length,
        totalFrames: roll.maxFrames,
      ),
    );
  }

  Widget _buildStateContent() {
    final roll = widget.roll;
    switch (roll.status) {
      case RollStatus.shooting:
        return _ShootingContent(
          rollId: roll.id,
          maxFrames: roll.maxFrames,
          guidanceExifKey: widget.guidanceExifKey,
          guidanceViewLogsKey: widget.guidanceViewLogsKey,
        );
      case RollStatus.lab:
        return _LabContent(
          rollId: roll.id,
          maxFrames: roll.maxFrames,
        );
      case RollStatus.scanned:
        return _buildScannedOrSyncingContent(roll);
      case RollStatus.syncing:
        return _buildScannedOrSyncingContent(roll);
      case RollStatus.archived:
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static Future<void> _showQuickStatusSheet(BuildContext context, WidgetRef ref, Roll roll) async {
    final rollService = ref.read(rollServiceProvider);
    final user = ref.read(userProvider);
    if (user == null) return;
    final token = await user.getIdToken();
    if (token == null) return;

    if (!context.mounted) return;
    showHalideModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatusSelector(
        currentStatus: roll.status,
        onStatusSelected: (RollStatus newStatus) async {
          try {
            await rollService.updateRollStatus(token, roll.id, newStatus.name);
            ref.refresh(dashboardRollsProvider);
            ref.invalidate(rollDetailProvider(roll.id));
            return true;
          } catch (_) {
            if (context.mounted) {
              ref.read(notificationProvider.notifier).show(
                'WE COULDN\'T UPDATE THE STATUS. PLEASE TRY AGAIN.',
                type: NotificationType.error,
              );
            }
            return false;
          }
        },
      ),
    );
  }

  Future<void> _showUrlBottomSheet(
    BuildContext context,
    Roll roll, {
    Future<void> Function(String driveUrl)? onSavedFetch,
  }) async {
    final initialValue = (roll.driveUrl ?? '').trim();
    await showHalideModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DriveUrlBottomSheet(
        rollId: roll.id,
        initialUrl: initialValue,
        onSavedFetch: onSavedFetch,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final RollStatus status;

  const _StatusBadge({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case RollStatus.shooting: color = Colors.orange; break;
      case RollStatus.lab: color = Colors.blue; break;
      case RollStatus.scanned: color = Colors.green; break;
      case RollStatus.syncing: color = Colors.blueAccent; break;
      case RollStatus.archived: color = Colors.grey; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _DriveUrlBottomSheet extends ConsumerStatefulWidget {
  final String rollId;
  final String initialUrl;
  final Future<void> Function(String driveUrl)? onSavedFetch;

  const _DriveUrlBottomSheet({
    required this.rollId,
    required this.initialUrl,
    this.onSavedFetch,
  });

  @override
  ConsumerState<_DriveUrlBottomSheet> createState() => _DriveUrlBottomSheetState();
}

class _DriveUrlBottomSheetState extends ConsumerState<_DriveUrlBottomSheet> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: HalideModalContainer(
        padding: const EdgeInsets.only(top: 32, left: 24, right: 24, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'LINK DRIVE URL',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            HalideTextField(
              controller: _controller,
              label: 'DRIVE LINK',
              prefixIcon: Icons.link_rounded,
            ),
            const SizedBox(height: 48),
            HalideActionButton(
              text: 'SAVE & SYNC',
              isLoading: _isSaving,
              onPressed: () async {
                final url = _controller.text.trim();
                if (url.isEmpty) return;
                dismissKeyboardGlobally();
                setState(() => _isSaving = true);
                try {
                  final gdriveOk = await ensureGoogleDriveConnected(context, ref);
                  if (!gdriveOk) {
                    if (mounted) setState(() => _isSaving = false);
                    return;
                  }
                  dismissKeyboardGlobally();
                  await _api.patch(
                    '/api/v1/rolls/${widget.rollId}/drive-url',
                    data: {'drive_url': url},
                  );
                  ref.invalidate(dashboardRollsProvider);
                  ref.invalidate(rollDetailProvider(widget.rollId));
                  if (context.mounted) Navigator.of(context).pop();
                  ref.read(syncGuidanceRollIdProvider.notifier).setPending(widget.rollId);
                  await widget.onSavedFetch?.call(url);
                } catch (e) {
                  if (!context.mounted) return;
                  setState(() => _isSaving = false);
                  ref.read(notificationProvider.notifier).show(
                    'COULDN\'T SAVE DRIVE LINK. PLEASE VERIFY THE URL.',
                    type: NotificationType.error,
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ShootingContent extends ConsumerWidget {
  final String rollId;
  final int maxFrames;
  final GlobalKey? guidanceExifKey;
  final GlobalKey? guidanceViewLogsKey;

  const _ShootingContent({
    Key? key,
    required this.rollId,
    required this.maxFrames,
    this.guidanceExifKey,
    this.guidanceViewLogsKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            '$maxFrames Frames',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                key: guidanceViewLogsKey,
                onPressed: () => context.push('/roll/$rollId'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'VIEW LOGS →',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
              IconButton(
                key: guidanceExifKey,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => ExifCaptureModal(
                      onLog: (aperture, shutter, lat, lng) async {
                        final rollService = ref.read(rollServiceProvider);
                        final user = ref.read(userProvider);
                        if (user == null) return;
                        final token = await user.getIdToken();
                        if (token == null) return;

                        try {
                          await rollService.logShot(
                            token,
                            rollId,
                            aperture: aperture,
                            shutterSpeed: shutter,
                            lat: lat,
                            lng: lng,
                          );
                          ref.invalidate(dashboardRollsProvider);
                          if (context.mounted) {
                            ref.read(notificationProvider.notifier).show(
                              'SHOT RECORDED!',
                              type: NotificationType.success,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ref.read(notificationProvider.notifier).show(
                              'COULDN\'T RECORD SHOT. PLEASE TRY AGAIN.',
                              type: NotificationType.error,
                            );
                          }
                        }
                      },
                    ),
                  );
                },
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.camera_rounded, color: Colors.orange, size: 20),
                ),
                tooltip: 'Record Shot',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabContent extends StatelessWidget {
  final String rollId;
  final int maxFrames;

  const _LabContent({
    Key? key,
    required this.rollId,
    required this.maxFrames,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            '$maxFrames Frames',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextButton(
            onPressed: () => context.push('/roll/$rollId'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'VIEW LOGS →',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScannedContent extends StatelessWidget {
  final String rollId;
  final List<String> imageUrls;
  final List<String> imageIds;
  final int actualFrames;
  final int totalFrames;

  const _ScannedContent({
    Key? key,
    required this.rollId,
    required this.imageUrls,
    required this.imageIds,
    required this.actualFrames,
    required this.totalFrames,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // [imageUrls] / [imageIds] are already paired from [RollGalleryPairs.tripleAsync]; do not re-filter
    // or indices drift from DB image ids.
    final urls = imageUrls;
    final effectiveActualFrames = urls.length;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => context.push('/roll/$rollId'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              '$effectiveActualFrames/$totalFrames Frames',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          if (urls.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: urls.length,
                itemBuilder: (context, index) {
                  final imageId = index < imageIds.length ? imageIds[index] : null;
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 140,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withOpacity(0.08),
                    ),
                    child: SyncedImage(
                      rollId: rollId,
                      imageUrl: urls[index],
                      imageId: imageId,
                      fit: BoxFit.cover,
                      preferThumbnail: false,
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextButton(
              onPressed: () => context.push('/roll/$rollId'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'OPEN GALLERY →',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
