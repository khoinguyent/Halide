import 'dart:async';
import 'package:flutter/material.dart';
import '../services/fetch_scans_helper.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/enum_l10n.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import '../models/roll.dart';
import '../config/app_config.dart';
import '../models/roll_gallery.dart';
import '../models/roll_status.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/halide_dialog.dart';
import '../core/theme/halide_colors.dart';
import '../core/theme/roll_status_colors.dart';
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
import '../providers/ui_state_provider.dart';
import '../features/storage/presentation/providers/free_lab_drive_sync_provider.dart';
import 'sync_progress_banner.dart';

/// Matches [RollDetailView] / [FolderTabs]: tab 1 is Shot Log.
const int _kRollDetailShotLogTabIndex = 1;

/// Whether this roll’s card shows the link/sync control (top-right next to the date).
/// Keep in sync with [RollCard] layout — [HomeView] uses this to decide when Drive/sync coach marks apply.
/// Free plans do not sync lab scans from a Drive URL (device photos only); personal Drive backup is separate.
bool rollShowsLinkSyncControl(Roll roll, WidgetRef ref) {
  if (ref.watch(userPlanProvider) == UserPlan.free) return false;
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
  /// Shooting roll intro: highlights the card (tap to open Shot Log).
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
    await FetchScansHelper.handleFetchScans(
      context: context,
      ref: ref,
      rollId: rollId,
      driveUrl: driveUrl,
      onFetchingStateChanged: (isFetching) {
        if (mounted) {
          setState(() {
            _fetchingRollId = isFetching ? rollId : null;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final roll = widget.roll;

    final showLinkFetchAction = rollShowsLinkSyncControl(roll, ref);
    final plan = ref.watch(userPlanProvider);
    final showGyroScanAction = AppConfig.enableGyroScan && roll.status == RollStatus.lab;

    final driveUrl = (roll.driveUrl ?? '').trim();
    final hasDriveUrl = driveUrl.isNotEmpty;

    return GlassPanel(
      key: widget.guidanceViewLogsKey,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          if (widget.guidanceViewLogsKey != null) {
            ref
                .read(rollTabStateProvider.notifier)
                .setTab(roll.id, _kRollDetailShotLogTabIndex);
          }
          context.push('/roll/${roll.id}');
        },
        borderRadius: BorderRadius.circular(24),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Status Badge and Timestamp only
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
                      Text(
                        _formatDate(roll.createdAt!),
                        style: TextStyle(
                          color: HalideColors.of(context).textSecondary,
                          fontSize: 12,
                        ),
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
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: HalideColors.of(context).textPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${roll.name} - ${roll.cameraName ?? "Unknown Camera"}${roll.lensName != null && roll.lensName!.trim().isNotEmpty ? " + ${roll.lensName!.trim()}" : ""}',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: HalideColors.of(context).textMuted(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      (roll.description?.trim().isNotEmpty ?? false)
                          ? roll.description!.trim()
                          : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: HalideColors.of(context).textMuted(0.65),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // State-specific content
              _buildStateContent(
                context: context,
                roll: roll,
                showGyroScanAction: showGyroScanAction,
                showLinkFetchAction: showLinkFetchAction,
                hasDriveUrl: hasDriveUrl,
                driveUrl: driveUrl,
                plan: plan,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      );
  }

  Widget _buildScannedOrSyncingContent(
    Roll roll, {
    required bool showLinkFetch,
    required bool hasDriveUrl,
    required bool isFetching,
    GlobalKey? guidanceLinkSyncKey,
    required Future<void> Function() onLinkSync,
  }) {
    final async = ref.watch(rollGalleryPairsProvider(roll.id));
    return async.when(
      loading: () => _ScannedContent(
        rollId: roll.id,
        imageUrls: const [],
        imageIds: const [],
        actualFrames: 0,
        totalFrames: roll.maxFrames,
        isSyncing: roll.status == RollStatus.syncing,
        showLinkFetch: showLinkFetch,
        hasDriveUrl: hasDriveUrl,
        isFetching: isFetching,
        guidanceLinkSyncKey: guidanceLinkSyncKey,
        onLinkSync: onLinkSync,
      ),
      error: (_, __) => _ScannedContent(
        rollId: roll.id,
        imageUrls: const [],
        imageIds: const [],
        actualFrames: 0,
        totalFrames: roll.maxFrames,
        isSyncing: roll.status == RollStatus.syncing,
        showLinkFetch: showLinkFetch,
        hasDriveUrl: hasDriveUrl,
        isFetching: isFetching,
        guidanceLinkSyncKey: guidanceLinkSyncKey,
        onLinkSync: onLinkSync,
      ),
      data: (triple) => _ScannedContent(
        rollId: roll.id,
        imageUrls: triple.$1,
        imageIds: triple.$2,
        actualFrames: triple.$1.length,
        totalFrames: roll.maxFrames,
        isSyncing: roll.status == RollStatus.syncing,
        showLinkFetch: showLinkFetch,
        hasDriveUrl: hasDriveUrl,
        isFetching: isFetching,
        guidanceLinkSyncKey: guidanceLinkSyncKey,
        onLinkSync: onLinkSync,
      ),
    );
  }

  Widget _buildStateContent({
    required BuildContext context,
    required Roll roll,
    required bool showGyroScanAction,
    required bool showLinkFetchAction,
    required bool hasDriveUrl,
    required String driveUrl,
    required UserPlan plan,
  }) {
    switch (roll.status) {
      case RollStatus.shooting:
        return _ShootingContent(
          rollId: roll.id,
          maxFrames: roll.maxFrames,
          shotCount: roll.shots.length,
          guidanceExifKey: widget.guidanceExifKey,
        );
      case RollStatus.lab:
        return _LabContent(
          roll: roll,
          showGyroScan: showGyroScanAction,
          showLinkFetch: showLinkFetchAction,
          hasDriveUrl: hasDriveUrl,
          driveUrl: driveUrl,
          isFetching: _fetchingRollId == roll.id,
          isPro: plan.isPro,
          guidanceLinkSyncKey: widget.guidanceLinkSyncKey,
          onGyroScan: () => _openGyroScan(context, roll.id, plan),
          onLinkSync: () async {
            if (_fetchingRollId == roll.id) return;
            if (hasDriveUrl) {
              await _handleFetchScans(roll.id, driveUrl);
            } else {
              await _showUrlBottomSheet(
                context,
                roll,
                onSavedFetch: (url) => _handleFetchScans(roll.id, url),
              );
            }
          },
        );
      case RollStatus.scanned:
        return _buildScannedOrSyncingContent(
          roll,
          showLinkFetch: showLinkFetchAction,
          hasDriveUrl: hasDriveUrl,
          isFetching: _fetchingRollId == roll.id,
          guidanceLinkSyncKey: widget.guidanceLinkSyncKey,
          onLinkSync: () async {
            if (_fetchingRollId == roll.id) return;
            if (hasDriveUrl) {
              await _handleFetchScans(roll.id, driveUrl);
            } else {
              await _showUrlBottomSheet(
                context,
                roll,
                onSavedFetch: (url) => _handleFetchScans(roll.id, url),
              );
            }
          },
        );
      case RollStatus.syncing:
        return _buildScannedOrSyncingContent(
          roll,
          showLinkFetch: false,
          hasDriveUrl: hasDriveUrl,
          isFetching: true,
          guidanceLinkSyncKey: widget.guidanceLinkSyncKey,
          onLinkSync: () async {},
        );
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
                halideCaps(context.l10n.couldNotUpdateStatus),
                type: NotificationType.error,
              );
            }
            return false;
          }
        },
      ),
    );
  }

  void _openGyroScan(BuildContext context, String rollId, UserPlan plan) {
    if (!plan.isPro) {
      context.push('/paywall');
      return;
    }
    context.push('/roll/$rollId/gyro-scan');
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
    final l10n = context.l10n;
    final color = RollStatusColors.forStatus(status, HalideColors.of(context));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            halideCaps(status.localizedLabel(l10n)),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 14,
            color: color,
          ),
        ],
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
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: HalideModalContainer(
        padding: const EdgeInsets.only(top: 32, left: 24, right: 24, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              halideCaps(l10n.driveLink),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HalideColors.of(context).textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            HalideTextField(
              controller: _controller,
              label: halideCaps(l10n.driveLink),
              prefixIcon: Icons.link_rounded,
            ),
            const SizedBox(height: 48),
            HalideActionButton(
              text: halideCaps(l10n.saveAndSync),
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

class _RollActionPill extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool loading;
  final Key? pillKey;
  final IconData? icon;

  const _RollActionPill({
    super.key,
    this.pillKey,
    required this.label,
    required this.color,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      key: pillKey,
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShootingContent extends ConsumerWidget {
  final String rollId;
  final int maxFrames;
  final int shotCount;
  final GlobalKey? guidanceExifKey;

  const _ShootingContent({
    Key? key,
    required this.rollId,
    required this.maxFrames,
    required this.shotCount,
    this.guidanceExifKey,
  }) : super(key: key);

  void _openExifModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExifCaptureModal(
        onLog: (aperture, shutter, lat, lng, notes) async {
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
              notes: notes,
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final progress = maxFrames > 0 ? (shotCount / maxFrames).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$shotCount / $maxFrames frames logged',
                style: TextStyle(color: HalideColors.of(context).textSecondary, fontSize: 13),
              ),
              SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  minHeight: 4,
                  backgroundColor: HalideColors.of(context).glassFill(0.08),
                  color: HalideColors.of(context).slateTeal,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _RollActionPill(
            pillKey: guidanceExifKey,
            label: halideCaps(l10n.logShot),
            color: HalideColors.of(context).slateTeal,
            icon: Icons.camera_rounded,
            onPressed: () => _openExifModal(context, ref),
          ),
        ),
      ],
    );
  }
}

class _LabContent extends ConsumerWidget {
  final Roll roll;
  final bool showGyroScan;
  final bool showLinkFetch;
  final bool hasDriveUrl;
  final String driveUrl;
  final bool isFetching;
  final bool isPro;
  final GlobalKey? guidanceLinkSyncKey;
  final VoidCallback onGyroScan;
  final Future<void> Function() onLinkSync;

  const _LabContent({
    Key? key,
    required this.roll,
    required this.showGyroScan,
    required this.showLinkFetch,
    required this.hasDriveUrl,
    required this.driveUrl,
    required this.isFetching,
    required this.isPro,
    this.guidanceLinkSyncKey,
    required this.onGyroScan,
    required this.onLinkSync,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freeSync = ref.watch(freeLabDriveSyncControllerProvider);
    final showFreeProgress = freeSync.isRunning && freeSync.rollId == roll.id;
    final showFetching = isFetching || roll.status == RollStatus.syncing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            '${roll.maxFrames} frames · At lab',
            style: TextStyle(color: HalideColors.of(context).textSecondary, fontSize: 13),
          ),
        ),
        if (showFreeProgress || showFetching) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SyncProgressInline(
              label: showFreeProgress
                  ? (freeSync.total > 0
                      ? 'Downloading ${freeSync.done}/${freeSync.total}'
                      : 'Starting download…')
                  : 'Syncing from Google Drive…',
              progress: showFreeProgress ? freeSync.progress : null,
              accentColor: HalideColors.of(context).sage,
            ),
          ),
        ],
        if (showLinkFetch) ...[
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _RollActionPill(
              pillKey: guidanceLinkSyncKey,
              label: hasDriveUrl ? 'SYNC SCANS' : 'ADD DRIVE LINK',
              color: HalideColors.of(context).sage,
              icon: hasDriveUrl
                  ? Icons.cloud_download
                  : Icons.link_outlined,
              loading: isFetching || roll.status == RollStatus.syncing || showFreeProgress,
              onPressed: () => onLinkSync(),
            ),
          ),
        ],
        if (showGyroScan) ...[
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _RollActionPill(
              label: isPro ? 'GYRO SCAN' : 'GYRO SCAN (PRO)',
              color: HalideColors.of(context).slateTeal,
              icon: isPro ? Icons.document_scanner_outlined : Icons.lock_outline,
              onPressed: onGyroScan,
            ),
          ),
        ],
      ],
    );
  }
}

class _ScannedContent extends ConsumerWidget {
  final String rollId;
  final List<String> imageUrls;
  final List<String> imageIds;
  final int actualFrames;
  final int totalFrames;
  final bool isSyncing;
  final bool showLinkFetch;
  final bool hasDriveUrl;
  final bool isFetching;
  final GlobalKey? guidanceLinkSyncKey;
  final Future<void> Function() onLinkSync;

  const _ScannedContent({
    Key? key,
    required this.rollId,
    required this.imageUrls,
    required this.imageIds,
    required this.actualFrames,
    required this.totalFrames,
    this.isSyncing = false,
    this.showLinkFetch = false,
    this.hasDriveUrl = false,
    this.isFetching = false,
    this.guidanceLinkSyncKey,
    required this.onLinkSync,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // [imageUrls] / [imageIds] are already paired from [RollGalleryPairs.tripleAsync]; do not re-filter
    // or indices drift from DB image ids.
    final urls = imageUrls;
    final effectiveActualFrames = urls.length;
    final freeSync = ref.watch(freeLabDriveSyncControllerProvider);
    final showFreeProgress = freeSync.isRunning && freeSync.rollId == rollId;
    final showAnyProgress = showFreeProgress || isSyncing || isFetching;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            showAnyProgress
                ? (showFreeProgress
                    ? freeSync.progressLabel
                    : 'Syncing scans…')
                : '$effectiveActualFrames/$totalFrames frames',
            style: TextStyle(color: HalideColors.of(context).textSecondary, fontSize: 13),
          ),
        ),
        if (showAnyProgress) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SyncProgressInline(
              label: showFreeProgress
                  ? (freeSync.total > 0
                      ? 'Downloading ${freeSync.done}/${freeSync.total}'
                      : 'Starting download…')
                  : 'Syncing from Google Drive…',
              progress: showFreeProgress ? freeSync.progress : null,
              accentColor: HalideColors.of(context).ash,
            ),
          ),
        ],
        if (urls.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
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
                    color: HalideColors.of(context).glassFill(0.08),
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
        if (showLinkFetch) ...[
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _RollActionPill(
              pillKey: guidanceLinkSyncKey,
              label: hasDriveUrl ? 'SYNC SCANS' : 'ADD DRIVE LINK',
              color: HalideColors.of(context).ash,
              icon: hasDriveUrl
                  ? Icons.cloud_download
                  : Icons.link_outlined,
              loading: isFetching || isSyncing || showFreeProgress,
              onPressed: () => onLinkSync(),
            ),
          ),
        ],
      ],
    );
  }
}
