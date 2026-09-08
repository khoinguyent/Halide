import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import 'package:frontend/core/l10n/enum_l10n.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../core/widgets/glass_panel.dart';
import '../core/theme/halide_colors.dart';
import '../core/theme/roll_status_colors.dart';
import '../models/roll.dart';
import '../models/roll_status.dart';
import '../models/film_stock.dart';
import '../models/camera.dart';
import '../models/user_profile.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/roll_provider.dart';
import '../services/public_drive_lab_import_service.dart';
import '../providers/rolls_provider.dart';
import '../features/rolls/presentation/bloc/rolls_bloc.dart';
import '../widgets/synced_image.dart';
import '../widgets/image_uploader_widget.dart';
import '../widgets/full_screen_viewer.dart';
import '../core/providers/notification_provider.dart';
import '../core/models/notification_model.dart';
import '../services/api_service.dart';
import '../services/upload_service.dart';
import '../core/widgets/image_placeholder.dart';
import '../services/gdrive_connection_guard.dart';
import '../services/local_sync_service.dart';
import '../models/shot.dart';
import '../models/roll_gallery.dart';
import '../widgets/folder_tabs.dart';
import '../widgets/status_selector.dart';
import '../providers/ui_state_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/sync_progress_banner.dart';

class RollDetailView extends ConsumerStatefulWidget {
  final String rollId;

  const RollDetailView({Key? key, required this.rollId}) : super(key: key);

  @override
  ConsumerState<RollDetailView> createState() => _RollDetailViewState();
}

class _RollDetailViewState extends ConsumerState<RollDetailView> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(rollDetailProvider(widget.rollId));
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    debugPrint('[RollDetail] Starting polling for sync...');
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      ref.invalidate(rollDetailProvider(widget.rollId));
    });
  }

  void _stopPolling() {
    if (_pollingTimer != null) {
      debugPrint('[RollDetail] Stopping polling.');
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rollAsync = ref.watch(rollDetailProvider(widget.rollId));

    return rollAsync.when(
      loading: () => Scaffold(
        backgroundColor: HalideColors.of(context).background,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: HalideColors.of(context).textPrimary),
        body: Center(child: CircularProgressIndicator(color: HalideColors.of(context).slateTeal)),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: HalideColors.of(context).background,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref.refresh(rollDetailProvider(widget.rollId)),
                  child: Text(context.l10n.retry, style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (roll) {
        if (roll.status == RollStatus.syncing) {
          if (_pollingTimer == null) _startPolling();
        } else {
          _stopPolling();
        }

        final plan = ref.read(userPlanProvider);
        if (plan != UserPlan.free) {
          ref.read(rollGalleryPairsProvider(roll.id).future).then((triple) {
            final httpUrls = <String>[];
            final httpIds = <String>[];
            for (var i = 0; i < triple.$1.length; i++) {
              final u = triple.$1[i];
              if (u.startsWith('http')) {
                httpUrls.add(u);
                httpIds.add(triple.$2[i]);
              }
            }
            if (httpUrls.isNotEmpty) {
              LocalSyncService().syncRoll(widget.rollId, httpUrls, imageIds: httpIds);
            }
          });
        }

        return _buildBody(context, roll);
      },
    );
  }

  Widget _buildBody(BuildContext context, Roll roll) {
    final galleryAsync = ref.watch(rollGalleryPairsProvider(roll.id));
    final triple = switch (galleryAsync) {
      AsyncData(:final value) => value,
      _ => RollGalleryPairs.tripleServerOnly(roll),
    };

    final isScanned = roll.status == RollStatus.scanned;
    final isArchived = roll.status == RollStatus.archived;
    final isShooting = roll.status == RollStatus.shooting;
    final selectedTabIndex = ref.watch(rollTabStateProvider)[widget.rollId] ?? 0;

    return Scaffold(
      backgroundColor: HalideColors.of(context).background,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                roll.title ?? '${roll.brand} ${roll.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, color: HalideColors.of(context).textPrimary),
              ),
            ),
            SizedBox(width: 12),
            _StatusBadge(
              status: roll.status,
              onTap: isArchived || roll.status == RollStatus.syncing
                  ? null
                  : () => _showStatusSelector(context, roll),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: HalideColors.of(context).textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (!isArchived && roll.status != RollStatus.syncing)
            roll.status == RollStatus.scanned
                ? _ArchiveRollHint(
                    onArchive: () => _confirmArchiveRoll(context),
                  )
                : _NextStepBanner(
                    status: roll.status,
                    onAdvance: () => _onNextStatusTapped(context),
                  ),
          FolderTabs(
            selectedIndex: selectedTabIndex,
            onTabSelected: (index) {
              ref.read(rollTabStateProvider.notifier).setTab(widget.rollId, index);
            },
            photoCount: triple.$1.length,
            shotCount: roll.shots.length,
          ),
          Expanded(
            child: IndexedStack(
              index: selectedTabIndex,
              children: [
                // Tab 0: Photos
                SingleChildScrollView(
                  key: const PageStorageKey('photos_tab'),
                  child: isScanned
                      ? _buildScannedBody(context, roll, triple)
                      : isArchived
                          ? _buildGalleryGrid(context, roll, triple, shrinkWrap: true, offset: roll.shotOffset)
                          : isShooting
                              ? _buildShootingMetaEditor(context, roll)
                              : _buildLabImportBody(context, roll, triple),
                ),
                // Tab 1: Shot Log
                SingleChildScrollView(
                  key: const PageStorageKey('shots_tab'),
                  child: _ShotLogSection(
                    roll: roll,
                    onOffsetChanged: (offset) async {
                      final rollService = ref.read(rollServiceProvider);
                      final user = ref.read(userProvider);
                      if (user == null) return;
                      final token = await user.getIdToken();
                      if (token == null) return;

                      await rollService.updateRollMeta(
                        token,
                        roll.id,
                        shotOffset: offset,
                      );
                      ref.invalidate(rollDetailProvider(roll.id));
                      ref.invalidate(rollGalleryPairsProvider(roll.id));
                      ref.invalidate(dashboardRollsProvider);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addPhotosToScannedRoll() async {
    final picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;

    final plan = ref.read(userPlanProvider);
    final user = ref.read(userProvider);
    if (user == null) return;
    final token = await user.getIdToken();
    if (token == null) return;

    if (plan == UserPlan.free) {
      final rollService = ref.read(rollServiceProvider);
      final paths = picked.map((x) => x.path).toList();
      try {
        await rollService.addLocalImagesToRoll(token, widget.rollId, paths);
        ref.invalidate(rollDetailProvider(widget.rollId));
        ref.invalidate(rollGalleryPairsProvider(widget.rollId));
        if (mounted) {
          ref.read(notificationProvider.notifier).show(
                halideCaps(context.l10n.addedLocalImageReferences),
                type: NotificationType.info,
              );
        }
      } catch (e) {
        if (mounted) {
          ref.read(notificationProvider.notifier).show(
                halideCaps(context.l10n.couldNotAddImageReferences),
                type: NotificationType.error,
              );
        }
      }
    } else {
      final uploader = UploadService();
      int successCount = 0;
      for (final xFile in picked) {
        final file = File(xFile.path);
        final ok = await uploader.uploadRollImage(
          rollId: widget.rollId,
          imageFile: file,
        );
        if (ok) successCount++;
      }
      if (successCount > 0) {
        ref.invalidate(rollDetailProvider(widget.rollId));
        ref.invalidate(rollGalleryPairsProvider(widget.rollId));
        if (mounted) {
          ref.read(notificationProvider.notifier).show(
                halideCaps(context.l10n.successfullyUploadedCount(successCount)),
                type: NotificationType.success,
              );
        }
      }
    }
  }

  Widget _buildScannedBody(BuildContext context, Roll roll, RollGalleryTriple triple) {
    final hasDisplayableImages = triple.$1.isNotEmpty;
    final hasDriveUrl = (roll.driveUrl ?? '').trim().isNotEmpty;
    // Drive-synced rolls: keep gallery as the lab delivery — no manual adds.
    // Manual / device-only rolls: allow adding more photos anytime.
    final canAddMore = !hasDriveUrl;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDriveUrl && hasDisplayableImages)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              l10n.scannedDriveSyncedHint,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        if (canAddMore && hasDisplayableImages)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addPhotosToScannedRoll,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(l10n.addMorePhotos),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        if (!hasDisplayableImages)
          SizedBox(
            height: 260,
            child: _buildGalleryGrid(
              context,
              roll,
              triple,
              shrinkWrap: true,
              emptyStateTopLeft: true,
              onEmptyStateTap: canAddMore ? _addPhotosToScannedRoll : null,
            ),
          )
        else
          _buildGalleryGrid(
            context,
            roll,
            triple,
            shrinkWrap: true,
            offset: roll.shotOffset,
            onAddMore: canAddMore ? _addPhotosToScannedRoll : null,
          ),
      ],
    );
  }

  Widget _buildLabImportBody(BuildContext context, Roll roll, RollGalleryTriple triple) {
    final hasImages = triple.$1.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasImages)
          Padding(
            padding: const EdgeInsets.all(20),
            child: _AtLabDualChoice(
              rollId: widget.rollId,
              onUploadComplete: () {
                ref.refresh(rollDetailProvider(widget.rollId));
                ref.invalidate(rollGalleryPairsProvider(widget.rollId));
                ref.invalidate(dashboardRollsProvider);
              },
            ),
          )
        else ...[
          if (AppConfig.enableGyroScan)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _GyroScanResumeBar(rollId: widget.rollId),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: GlassPanel(
              padding: const EdgeInsets.all(20),
              child: _LabImportOptions(
                rollId: widget.rollId,
                onUploadComplete: () {
                  ref.refresh(rollDetailProvider(widget.rollId));
                  ref.invalidate(rollGalleryPairsProvider(widget.rollId));
                  ref.invalidate(dashboardRollsProvider);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              context.l10n.uploadedImages,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildGalleryGrid(context, roll, triple, shrinkWrap: true, offset: roll.shotOffset),
        ],
      ],
    );
  }

  Widget _buildGalleryGrid(
    BuildContext context,
    Roll roll,
    RollGalleryTriple triple, {
    bool shrinkWrap = false,
    bool emptyStateTopLeft = false,
    VoidCallback? onEmptyStateTap,
    VoidCallback? onAddMore,
    int offset = 0,
  }) {
    final (pairedUrls, pairedIds, shotsAligned) = triple;
    final images = pairedUrls;

    if (images.isEmpty) {
      const crossAxisCount = 3;
      const gridPadding = 12.0;
      const crossAxisSpacing = 10.0;
      return LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
          final cellWidth = (availableWidth - (gridPadding * 2) - ((crossAxisCount - 1) * crossAxisSpacing)) /
              crossAxisCount;
          final size = (cellWidth > 0 ? cellWidth : 120.0);

          final square = SizedBox(
            width: size,
            height: size,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.18), width: 2),
                color: Colors.white.withOpacity(0.04),
              ),
              child: const Center(
                child: Icon(
                  Icons.add_rounded,
                  size: 28,
                  color: Colors.white70,
                ),
              ),
            ),
          );

          final built = onEmptyStateTap == null
              ? square
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEmptyStateTap,
                  child: square,
                );

          return emptyStateTopLeft
              ? Padding(
                  padding: const EdgeInsets.all(gridPadding),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: built,
                  ),
                )
              : Center(child: built);
        },
      );
    }

    final showAddCell = onAddMore != null;
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: images.length + (showAddCell ? 1 : 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        if (showAddCell && index == images.length) {
          return GestureDetector(
            onTap: onAddMore,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.18), width: 2),
                color: Colors.white.withOpacity(0.04),
              ),
              child: const Center(
                child: Icon(Icons.add_rounded, size: 28, color: Colors.white70),
              ),
            ),
          );
        }
        final path = images[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => FullScreenViewer(
                  rollId: roll.id,
                  imageUrls: images,
                  imageIds: pairedIds,
                  initialIndex: index,
                  iso: roll.shotAtIso,
                  dateScanned: roll.createdAt,
                  filmStock: FilmStock(id: roll.filmStockId, brand: roll.brand, name: roll.name, iso: roll.shotAtIso ?? 400, format: '135', colorType: 'Color'),
                  camera: Camera(id: roll.userCameraId, brand: roll.brand, model: roll.cameraName ?? 'Unknown', nickname: roll.nickname ?? ''),
                  shots: shotsAligned.map((s) => s.toJson()).toList(),
                  shotOffset: roll.shotOffset,
                ),
              ),
            );
          },
          child: Hero(
            tag: '$index-$path',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SyncedImage(
                    rollId: roll.id,
                    imageUrl: path,
                    imageId: index < pairedIds.length ? pairedIds[index] : null,
                    fit: BoxFit.cover,
                    preferThumbnail: false,
                  ),
                  if (offset > 0 || shotsAligned.isNotEmpty)
                    _buildOverlayMetadata(index, offset, shotsAligned),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlayMetadata(int imageIndex, int offset, List<Shot> galleryShots) {
    final shotIndex = imageIndex;
    if (shotIndex < 0 || shotIndex >= galleryShots.length) {
      return const SizedBox.shrink();
    }
    final shot = galleryShots[shotIndex];

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
          ),
        ),
        child: Row(
          children: [
            Text(
              '#${shotIndex + 1}',
              style: const TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(
              shot.aperture != null ? 'f/${shot.aperture}' : context.l10n.apertureMissing,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStatusSelector(BuildContext context, Roll roll) async {
    if (roll.status == RollStatus.archived || roll.status == RollStatus.syncing) {
      return;
    }

    await showHalideModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatusSelector(
        currentStatus: roll.status,
        onStatusSelected: (RollStatus newStatus) async {
          if (newStatus == roll.status) return true;
          try {
            await _onStatusSelected(context, newStatus);
            return true;
          } catch (_) {
            return false;
          }
        },
      ),
    );
  }

  static RollStatus? _nextStatus(RollStatus current) {
    if (current == RollStatus.archived || current == RollStatus.syncing) {
      return null;
    }
    const userFlow = [
      RollStatus.shooting,
      RollStatus.lab,
      RollStatus.scanned,
      RollStatus.archived,
    ];
    final idx = userFlow.indexOf(current);
    if (idx < 0 || idx >= userFlow.length - 1) return null;
    return userFlow[idx + 1];
  }

  Future<void> _onNextStatusTapped(BuildContext context) async {
    final rollAsync = ref.read(rollDetailProvider(widget.rollId));
    final roll = rollAsync.asData?.value;
    if (roll == null) return;

    final next = _nextStatus(roll.status);
    if (next == null || next == RollStatus.archived) return;
    await _onStatusSelected(context, next);
  }

  Future<void> _confirmArchiveRoll(BuildContext context) async {
    final l10n = context.l10n;
    final colors = HalideColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceSheet,
        title: Text(
          l10n.moveToArchiveTitle,
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          l10n.moveToArchiveBody,
          style: TextStyle(color: colors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel, style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.archiveAction,
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _onStatusSelected(context, RollStatus.archived);
  }

  Future<void> _onStatusSelected(BuildContext context, RollStatus newStatus) async {
    final rollService = ref.read(rollServiceProvider);
    final user = ref.read(userProvider);
    if (user == null) return;
    final token = await user.getIdToken();
    if (token == null) return;
    try {
      await rollService.updateRollStatus(token, widget.rollId, newStatus.name);
      ref.refresh(rollDetailProvider(widget.rollId));
      ref.invalidate(dashboardRollsProvider);
    } catch (_) {
      if (mounted) {
        ref.read(notificationProvider.notifier).show(
          halideCaps(context.l10n.couldNotUpdateStatus),
          type: NotificationType.error,
        );
      }
    }
  }

  Widget _buildShootingMetaEditor(BuildContext context, Roll roll) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPanel(
            padding: const EdgeInsets.all(20),
            child: _RollMetaEditor(
              initialTitle: roll.title ?? '',
              initialDescription: roll.description ?? '',
              onSave: (title, description) async {
                final rollService = ref.read(rollServiceProvider);
                final user = ref.read(userProvider);
                if (user == null) return;
                final token = await user.getIdToken();
                if (token == null) return;

                await rollService.updateRollMeta(
                  token,
                  widget.rollId,
                  title: title,
                  description: description,
                );
                ref.refresh(rollDetailProvider(widget.rollId));
                ref.invalidate(dashboardRollsProvider);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShotLogSection extends StatelessWidget {
  final Roll roll;
  final Function(int) onOffsetChanged;

  const _ShotLogSection({
    Key? key,
    required this.roll,
    required this.onOffsetChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shots = roll.shots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (roll.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AlignmentCalibrationSlider(
                    initialOffset: roll.shotOffset,
                    onChanged: onOffsetChanged,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(Icons.list_alt_rounded, size: 14, color: Colors.white.withOpacity(0.3)),
              const SizedBox(width: 8),
              Text(
                l10n.technicalDataCount(shots.length),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (shots.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                l10n.noTechnicalLogs,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          ),
        ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: shots.length,
          itemBuilder: (context, index) {
            final shot = shots[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassPanel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                shot.aperture != null ? 'f/${shot.aperture}' : context.l10n.apertureMissing,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 12),
                              Text(shot.shutterSpeed ?? '—', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                            ],
                          ),
                          if (shot.createdAt != null)
                            Text(
                              TimeOfDay.fromDateTime(shot.createdAt!).format(context),
                              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                            ),
                          if (shot.notes != null && shot.notes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              shot.notes!,
                              style: TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 11, height: 1.35),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (shot.locationLat != null && shot.locationLng != null)
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.white.withOpacity(0.2)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── Next step banner ─────────────────────────────────────────────────────────

class _NextStepBanner extends StatelessWidget {
  final RollStatus status;
  final VoidCallback onAdvance;

  const _NextStepBanner({
    required this.status,
    required this.onAdvance,
  });

  static String _nextLabel(RollStatus next, AppLocalizations l10n) {
    switch (next) {
      case RollStatus.lab:
        return halideCaps(l10n.sendToLab);
      case RollStatus.scanned:
        return halideCaps(l10n.markScanned);
      case RollStatus.archived:
        return halideCaps(l10n.archiveAction);
      default:
        return halideCaps(next.localizedLabel(l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = HalideColors.of(context);
    final next = _RollDetailViewState._nextStatus(status);
    if (next == null || next == RollStatus.archived) {
      return const SizedBox.shrink();
    }

    final color = RollStatusColors.forStatus(next, colors);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAdvance,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(color: color.withOpacity(0.25)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.arrow_forward_rounded, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.nextStepLabel(_nextLabel(next, l10n)),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: color.withOpacity(0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle affordance when scans are done — archive is optional housekeeping, not a workflow step.
class _ArchiveRollHint extends StatelessWidget {
  const _ArchiveRollHint({required this.onArchive});

  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = HalideColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 14, color: colors.iconMuted()),
          const SizedBox(width: 6),
          Text(
            l10n.scansComplete,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            ' · ',
            style: TextStyle(color: colors.iconMuted(), fontSize: 12),
          ),
          TextButton(
            onPressed: onArchive,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: colors.textSecondary,
            ),
            child: Text(
              l10n.moveToArchiveLink,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: colors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final RollStatus status;
  final VoidCallback? onTap;

  const _StatusBadge({
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fg = RollStatusColors.forStatus(status, HalideColors.of(context));
    final bg = fg.withValues(alpha: status == RollStatus.archived ? 0.22 : 0.16);
    final isArchived = status == RollStatus.archived;

    return InkWell(
      onTap: isArchived ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: fg.withOpacity(isArchived ? 0.4 : 0.9),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isArchived ? Icons.inventory_2_outlined : Icons.radio_button_checked,
              size: 14,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              halideCaps(status.localizedLabel(l10n)),
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: fg,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RollMetaEditor extends ConsumerStatefulWidget {
  final String initialTitle;
  final String initialDescription;
  final Future<void> Function(String title, String description) onSave;

  const _RollMetaEditor({
    required this.initialTitle,
    required this.initialDescription,
    required this.onSave,
  });

  @override
  ConsumerState<_RollMetaEditor> createState() => _RollMetaEditorState();
}

class _RollMetaEditorState extends ConsumerState<_RollMetaEditor> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.rollInfoSection,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: l10n.title,
            labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.blueAccent),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          style: const TextStyle(color: Colors.white),
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: l10n.description,
            labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.blueAccent),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _isSaving
                ? null
                : () async {
                    setState(() => _isSaving = true);
                    try {
                      final title = _titleController.text.trim();
                      final description = _descriptionController.text.trim();
                      await widget.onSave(title, description);
                      if (context.mounted) {
                        ref.read(notificationProvider.notifier).show(
                          halideCaps(l10n.rollInfoUpdated),
                          type: NotificationType.success,
                        );
                      }
                    } catch (e) {
                        ref.read(notificationProvider.notifier).show(
                          halideCaps(l10n.couldNotUpdateRollInfo),
                          type: NotificationType.error,
                        );
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.95),
              foregroundColor: Colors.black,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    l10n.save.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
          ),
        ),
      ],
    );
  }
}

enum _LabImportMode { manual, drive }

class _AtLabDualChoice extends ConsumerStatefulWidget {
  final String rollId;
  final VoidCallback onUploadComplete;

  const _AtLabDualChoice({
    required this.rollId,
    required this.onUploadComplete,
  });

  @override
  ConsumerState<_AtLabDualChoice> createState() => _AtLabDualChoiceState();
}

class _AtLabDualChoiceState extends ConsumerState<_AtLabDualChoice> {
  final TextEditingController _driveUrlController = TextEditingController();
  final ApiService _api = ApiService();
  bool _isSubmittingDrive = false;
  String? _driveError;

  @override
  void dispose() {
    _driveUrlController.dispose();
    super.dispose();
  }

  Future<void> _markRollScannedIfPossible() async {
    final user = ref.read(userProvider);
    final token = await user?.getIdToken();
    if (token == null) return;
    try {
      await ref.read(rollServiceProvider).updateRollStatus(token, widget.rollId, 'scanned');
    } catch (e) {
      debugPrint('[AtLab] could not set roll scanned: $e');
    }
  }

  Future<void> _onFreeDeviceUploadComplete() async {
    await _markRollScannedIfPossible();
    widget.onUploadComplete();
  }

  Future<void> _submitDriveUrl() async {
    final l10n = context.l10n;
    if (ref.read(userPlanProvider) == UserPlan.free) {
      setState(() => _driveError = l10n.driveLabSyncProOnly);
      return;
    }

    final url = _driveUrlController.text.trim();
    if (url.isEmpty) {
      setState(() => _driveError = l10n.pasteDriveLinkError);
      return;
    }

    final user = ref.read(userProvider);
    if (user == null) {
      setState(() => _driveError = l10n.signInToSyncDrive);
      return;
    }

    dismissKeyboardGlobally();
    setState(() {
      _isSubmittingDrive = true;
      _driveError = null;
    });

    try {
      final gdriveOk = await ensureGoogleDriveConnected(context, ref);
      if (!gdriveOk) return;

      await _api.patch(
        '/api/v1/rolls/${widget.rollId}/drive-url',
        data: {'drive_url': url},
      );

      if (!mounted) return;
      ref.invalidate(rollDetailProvider(widget.rollId));
      ref.invalidate(dashboardRollsProvider);

      ref.read(notificationProvider.notifier).show(
        halideCaps(l10n.driveLinkSavedSyncing),
        type: NotificationType.info,
      );

      final resp = await _api.post(
        '/api/v1/storage/gdrive/sync_images_from_url',
        data: {
          'roll_id': widget.rollId,
          'gdrive_url_or_id': url,
        },
      );

      if (!mounted) return;
      widget.onUploadComplete();

      final data = resp.data;
      if (data is Map && data['detail'] == 'Sync started in background') {
        ref.read(notificationProvider.notifier).show(
          halideCaps(l10n.syncStartedInBackground),
          type: NotificationType.info,
        );
      } else {
        final synced = (data is Map && data['synced_count'] != null)
            ? data['synced_count'].toString()
            : '0';
        ref.read(notificationProvider.notifier).show(
          halideCaps(l10n.importedPhotosFromDrive(synced)),
          type: NotificationType.success,
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data is Map
          ? (e.response?.data as Map)['detail']?.toString()
          : e.message;
      setState(() => _driveError = detail ?? l10n.couldNotSyncFromDrive);
    } catch (e) {
      if (mounted) {
        setState(
          () => _driveError = e.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingDrive = false);
    }
  }

  void _openGyroScan() {
    final plan = ref.read(userPlanProvider);
    if (!plan.isPro) {
      context.push('/paywall');
      return;
    }
    context.push('/roll/${widget.rollId}/gyro-scan');
  }

  Widget _buildFreeDeviceImportCard(AppLocalizations l10n) {
    return _DualChoiceCard(
      icon: Icons.photo_library_outlined,
      iconColor: Colors.tealAccent,
      title: l10n.atLabAddFromDevice,
      subtitle: l10n.atLabAddFromDeviceSubtitle,
      child: ImageUploaderWidget(
        rollId: widget.rollId,
        onUploadComplete: () {
          _onFreeDeviceUploadComplete();
        },
        darkMode: true,
        readOnly: false,
      ),
    );
  }

  Widget _buildProDriveSyncCard(AppLocalizations l10n) {
    return _DualChoiceCard(
      icon: Icons.cloud_sync_rounded,
      iconColor: Colors.blueAccent,
      title: l10n.labDigitalSync,
      subtitle: l10n.labDigitalSyncSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _driveUrlController,
            enabled: !_isSubmittingDrive,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: l10n.driveUrlHint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.28)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.blueAccent),
              ),
            ),
          ),
          if (_driveError != null) ...[
            const SizedBox(height: 8),
            Text(_driveError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
          const SizedBox(height: 10),
          Text(
            l10n.atLabNoDriveUrlHint,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (_isSubmittingDrive) ...[
            const SizedBox(height: 12),
            const SyncProgressBanner(
              label: 'Syncing scans from Google Drive…',
              progress: null,
              accentColor: Colors.blueAccent,
              compact: true,
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _isSubmittingDrive ? null : _submitDriveUrl,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.95),
                foregroundColor: Colors.black,
                shape: const StadiumBorder(),
              ),
              child: _isSubmittingDrive
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.submitAndSync, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plan = ref.watch(userPlanProvider);
    final isFree = plan == UserPlan.free;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.atLabSection,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isFree ? l10n.chooseLabImportMethodFree : l10n.chooseLabImportMethod,
          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
        ),
        const SizedBox(height: 20),
        if (isFree)
          _buildFreeDeviceImportCard(l10n)
        else
          _buildProDriveSyncCard(l10n),
        const SizedBox(height: 16),
        if (AppConfig.enableGyroScan)
          _DualChoiceCard(
            icon: Icons.document_scanner_outlined,
            iconColor: Colors.orange,
            title: l10n.cameraScanning,
            subtitle: l10n.cameraScanningSubtitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _openGyroScan,
                    icon: Icon(plan.isPro ? Icons.camera_alt_rounded : Icons.lock_outline_rounded),
                    label: Text(l10n.scanNegatives),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.withOpacity(0.92),
                      foregroundColor: Colors.black,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                if (!plan.isPro) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.premiumGyroScanFeatureHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Resume gyro scanning while roll is still at lab (multi-session scanning).
class _GyroScanResumeBar extends ConsumerWidget {
  final String rollId;

  const _GyroScanResumeBar({required this.rollId});

  void _openGyroScan(BuildContext context, WidgetRef ref) {
    final plan = ref.read(userPlanProvider);
    if (!plan.isPro) {
      context.push('/paywall');
      return;
    }
    context.push('/roll/$rollId/gyro-scan');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plan = ref.watch(userPlanProvider);

    return Material(
      color: Colors.orange.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _openGyroScan(context, ref),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                plan.isPro ? Icons.document_scanner_outlined : Icons.lock_outline_rounded,
                color: Colors.orange,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.continueGyroScan,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      plan.isPro
                          ? l10n.continueGyroScanHint
                          : l10n.premiumGyroScanResumeHint,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.orange),
            ],
          ),
        ),
      ),
    );
  }
}

class _DualChoiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;

  const _DualChoiceCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _LabImportOptions extends ConsumerStatefulWidget {
  final String rollId;
  final VoidCallback onUploadComplete;

  const _LabImportOptions({
    required this.rollId,
    required this.onUploadComplete,
  });

  @override
  ConsumerState<_LabImportOptions> createState() => _LabImportOptionsState();
}

class _LabImportOptionsState extends ConsumerState<_LabImportOptions> {
  _LabImportMode _mode = _LabImportMode.manual;

  final TextEditingController _driveUrlController = TextEditingController();
  final ApiService _api = ApiService();

  int _manualUploadResetToken = 0;
  bool _manualUploadDone = false;

  bool _isFetching = false;
  String? _error;
  List<Map<String, dynamic>> _leafFiles = const [];

  bool _isDriveFolderUrl(String url) => url.contains('/folders/');

  bool _isDriveZipUrl(String url) => url.contains('/file/d/');

  @override
  void dispose() {
    _driveUrlController.dispose();
    super.dispose();
  }

  Future<void> _markRollScannedIfPossible() async {
    final user = ref.read(userProvider);
    final token = await user?.getIdToken();
    if (token == null) return;
    try {
      await ref.read(rollServiceProvider).updateRollStatus(token, widget.rollId, 'scanned');
    } catch (e) {
      debugPrint('[LabImport] could not set roll scanned: $e');
    }
  }

  Future<void> _afterLocalLabImport(int count) async {
    await _markRollScannedIfPossible();
    ref.invalidate(rollDetailProvider(widget.rollId));
    ref.invalidate(rollGalleryPairsProvider(widget.rollId));
    ref.invalidate(rollHasLocalLabScansProvider(widget.rollId));
    ref.invalidate(dashboardRollsProvider);
    widget.onUploadComplete();
    if (mounted) {
      ref.read(notificationProvider.notifier).show(
        halideCaps(context.l10n.savedPhotosOnDevice(count)),
        type: NotificationType.success,
      );
    }
  }

  Future<void> _fetchLeafFiles() async {
    final l10n = context.l10n;
    if (ref.read(userPlanProvider) == UserPlan.free) {
      setState(() => _error = l10n.driveLabSyncProOnly);
      return;
    }

    final url = _driveUrlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = l10n.pleasePasteDriveUrl);
      return;
    }

    final user = ref.read(userProvider);
    if (user == null) {
      setState(() => _error = l10n.mustSignInDriveSync);
      return;
    }

    dismissKeyboardGlobally();

    // Public ZIP or single image file: save under app documents (no Google account).
    if (!_isDriveFolderUrl(url)) {
      setState(() {
        _isFetching = true;
        _error = null;
        _leafFiles = const [];
      });
      try {
        final count = await PublicDriveLabImportService.importPublicFileOrZipToLocal(
          rollId: widget.rollId,
          driveUrlOrId: url,
        );
        if (!mounted) return;
        if (count > 0) {
          await _afterLocalLabImport(count);
          return;
        }
      } catch (e) {
        debugPrint('[LabImport] local import failed, trying cloud sync: $e');
        if (mounted) {
          ref.read(notificationProvider.notifier).show(
            halideCaps(l10n.tryingCloudSync),
            type: NotificationType.info,
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isFetching = false);
        }
      }
    }

    final gdriveOk = await ensureGoogleDriveConnected(context, ref);
    if (!gdriveOk) {
      return;
    }

    setState(() {
      _isFetching = true;
      _error = null;
      _leafFiles = const [];
    });

    // ZIP URLs cannot be pre-listed at leaf level reliably, so we directly sync (Pro cloud only).
    if (_isDriveZipUrl(url) && !_isDriveFolderUrl(url)) {
      try {
        if (!mounted) return;
        ref.read(notificationProvider.notifier).show(
          halideCaps(l10n.zipDetectedSyncing),
          type: NotificationType.info,
        );
        await _syncImagesFromUrl();
      } catch (_) {
        // Error handling happens inside _syncImagesFromUrl().
      } finally {
        if (mounted) {
          setState(() => _isFetching = false);
        }
      }
      return;
    }

    try {
      // Only folders can be pre-listed for preview.
      if (_isDriveFolderUrl(url)) {
        final resp = await _api.post(
          // Backend route is `/api/v1/storage/gdrive/list_leaf_files`.
          '/api/v1/storage/gdrive/list_leaf_files',
          data: {'folder_url_or_id': url},
        );

        final data = resp.data;
        if (data is List) {
          final parsed = <Map<String, dynamic>>[];
          for (final e in data) {
            if (e is Map) {
              parsed.add(Map<String, dynamic>.from(e));
            }
          }
          _leafFiles = parsed;
          // This is Flutter log, so it will appear in the `flutter run` terminal.
          debugPrint('[Drive] list_leaf_files: total=${data.length}, parsed=${_leafFiles.length}');
        } else {
          debugPrint('[Drive] list_leaf_files: unexpected payload type=${data.runtimeType}');
          _leafFiles = const [];
          _error = l10n.unexpectedDriveResponse;
        }
      } else {
        // If it's not clearly a folder or zip, just fall back to sync via auto-router.
        _leafFiles = const [];
      }

      if (!mounted) return;
      debugPrint('[Drive] auto-sync starting (leafFiles=${_leafFiles.length})');
      if (_isDriveFolderUrl(url)) {
        ref.read(notificationProvider.notifier).show(
          halideCaps(l10n.foundPhotosImporting(_leafFiles.length)),
          type: NotificationType.info,
        );
      }
      await _syncImagesFromUrl();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final detail = data is Map<String, dynamic> ? data['detail']?.toString() : data?.toString();
      setState(() {
        _error = detail != null && detail.isNotEmpty
            ? l10n.backendErrorDetail(status != null ? ' ($status)' : '', detail)
            : e.toString();
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _prefetchAfterSync() async {
    try {
      final roll = await ref.read(rollDetailProvider(widget.rollId).future);
      final triple = await RollGalleryPairs.tripleAsync(roll);
      final urls = <String>[];
      final ids = <String>[];
      for (var i = 0; i < triple.$1.length; i++) {
        if (triple.$1[i].startsWith('http')) {
          urls.add(triple.$1[i]);
          ids.add(triple.$2[i]);
        }
      }
      if (urls.isEmpty) return;
      await LocalSyncService().syncRollParallel(roll.id, urls, imageIds: ids);
    } catch (e) {
      debugPrint('[Drive] prefetch after sync: $e');
    }
  }

  Future<void> _syncImagesFromUrl() async {
    try {
      final gdriveOk = await ensureGoogleDriveConnected(context, ref);
      if (!gdriveOk) {
        return;
      }

      final url = _driveUrlController.text.trim();
      final resp = await _api.post(
        '/api/v1/storage/gdrive/sync_images_from_url',
        data: {
          'roll_id': widget.rollId,
          'gdrive_url_or_id': url,
        },
      );
      if (!mounted) return;
      final data = resp.data;
      ref.invalidate(rollDetailProvider(widget.rollId));
      ref.invalidate(rollGalleryPairsProvider(widget.rollId));
      if (data is Map && data['detail'] == 'Sync started in background') {
        widget.onUploadComplete();
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) _prefetchAfterSync();
        });
      } else {
        final synced = (data is Map && data['synced_count'] != null)
            ? data['synced_count'].toString()
            : '0';
        ref.read(notificationProvider.notifier).show(
          halideCaps(context.l10n.successfullyImportedNewPhotos(synced)),
          type: NotificationType.success,
        );
        widget.onUploadComplete();
        await _prefetchAfterSync();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      debugPrint('[Drive] sync error: ${e.response?.statusCode} $body');
      ref.read(notificationProvider.notifier).show(
        halideCaps(context.l10n.syncFailedVerifyDrive),
        type: NotificationType.error,
      );
    } catch (e) {
      ref.read(notificationProvider.notifier).show(
        halideCaps(context.l10n.somethingWrongDuringSync),
        type: NotificationType.error,
      );
    }
  }

  void _onManualUploadComplete() {
    // Ensure the manual uploader goes back to an empty state so the next
    // upload starts from a clean slate.
    setState(() {
      _manualUploadResetToken++;
      _manualUploadDone = true;
      _mode = _LabImportMode.manual;
    });
    widget.onUploadComplete();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPro = ref.watch(userPlanProvider).isPro;
    final showProProgress = _isFetching && isPro;
    // Free: device photos only — never show Drive URL mode.
    final mode = isPro ? _mode : _LabImportMode.manual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.importOptions,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ChoiceChip(
              label: Text(l10n.manualAddFree),
              selected: mode == _LabImportMode.manual,
              onSelected: (_) => setState(() => _mode = _LabImportMode.manual),
            ),
            if (isPro && !_manualUploadDone) ...[
              ChoiceChip(
                label: Text(l10n.driveUrlChip),
                selected: mode == _LabImportMode.drive,
                onSelected: (_) => setState(() => _mode = _LabImportMode.drive),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        if (showProProgress) ...[
          const SyncProgressBanner(
            label: 'Syncing scans from Google Drive…',
            progress: null,
            accentColor: Colors.blueAccent,
            compact: true,
          ),
          const SizedBox(height: 14),
        ],
        if (mode == _LabImportMode.manual)
          ImageUploaderWidget(
            key: ValueKey('manual-uploader-$_manualUploadResetToken'),
            rollId: widget.rollId,
            onUploadComplete: _onManualUploadComplete,
            darkMode: true,
            readOnly: false,
          )
        else ...[
          TextField(
            controller: _driveUrlController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: l10n.driveUrlLabel,
              labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.blueAccent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _isFetching ? null : _fetchLeafFiles,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.95),
                foregroundColor: Colors.black,
                shape: const StadiumBorder(),
              ),
              child: _isFetching
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      l10n.fetchFiles,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 12),
          if (_leafFiles.isNotEmpty) ...[
            Text(
              l10n.foundFilesAtLeaf(_leafFiles.length),
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: GridView.builder(
                itemCount: _leafFiles.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final file = _leafFiles[index];
                  final mimeType = (file['mimeType'] as String?) ?? '';
                  final isImage = mimeType.startsWith('image/') ||
                      (file['name'] as String?)?.toLowerCase().endsWith('.jpg') == true ||
                      (file['name'] as String?)?.toLowerCase().endsWith('.jpeg') == true ||
                      (file['name'] as String?)?.toLowerCase().endsWith('.png') == true;
                  final id = file['id'] as String?;
                  // Drive preview URL pattern; this uses the file id.
                  final previewUrl = id != null ? 'https://drive.google.com/uc?id=$id&export=view' : null;

                  if (!isImage || previewUrl == null) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withOpacity(0.04),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.insert_drive_file_outlined,
                          size: 20,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    );
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      previewUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.white.withOpacity(0.05),
                          child: const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white38,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.white.withOpacity(0.04),
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 20,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _AlignmentCalibrationSlider extends StatefulWidget {
  final int initialOffset;
  final Function(int) onChanged;

  const _AlignmentCalibrationSlider({
    Key? key,
    required this.initialOffset,
    required this.onChanged,
  }) : super(key: key);

  @override
  _AlignmentCalibrationSliderState createState() => _AlignmentCalibrationSliderState();
}

class _AlignmentCalibrationSliderState extends State<_AlignmentCalibrationSlider> {
  late double _localOffset;

  @override
  void initState() {
    super.initState();
    _localOffset = widget.initialOffset.toDouble();
  }

  @override
  void didUpdateWidget(_AlignmentCalibrationSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialOffset != widget.initialOffset) {
      _localOffset = widget.initialOffset.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.tune_rounded, size: 14, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              l10n.alignmentCalibration,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w900,
                color: Colors.orange,
              ),
            ),
            const Spacer(),
            Text(
              l10n.framesOffset(_localOffset.toInt()),
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l10n.alignmentCalibrationHint,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: _localOffset,
            min: 0,
            max: 10,
            divisions: 10,
            activeColor: Colors.orange,
            inactiveColor: Colors.white10,
            onChanged: (v) {
              setState(() {
                _localOffset = v;
              });
            },
            onChangeEnd: (v) => widget.onChanged(v.toInt()),
          ),
        ),
      ],
    );
  }
}
