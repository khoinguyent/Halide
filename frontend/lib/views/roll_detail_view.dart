import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import '../core/widgets/glass_panel.dart';
import '../models/roll.dart';
import '../models/roll_status.dart';
import '../models/film_stock.dart';
import '../models/camera.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/roll_provider.dart';
import '../services/public_drive_lab_import_service.dart';
import '../services/authenticated_drive_folder_import_service.dart';
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
import '../providers/ui_state_provider.dart';
import '../providers/dashboard_provider.dart';

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
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
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
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
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
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                roll.title ?? '${roll.brand} ${roll.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            _StatusBadge(
              status: roll.status,
              onTap: isShooting ? null : () => _onNextStatusTapped(context),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
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

  Widget _buildScannedBody(BuildContext context, Roll roll, RollGalleryTriple triple) {
    final hasDisplayableImages = triple.$1.isNotEmpty;

    if (hasDisplayableImages) {
      return _buildGalleryGrid(context, roll, triple, shrinkWrap: true, offset: roll.shotOffset);
    }

    Future<void> _handleImagesAddition() async {
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
              'ADDED LOCAL IMAGE REFERENCES (FREE TIER).',
              type: NotificationType.info,
            );
          }
        } catch (e) {
          if (mounted) {
            ref.read(notificationProvider.notifier).show(
              'COULDN\'T ADD IMAGE REFERENCES. PLEASE TRY AGAIN.',
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
              'SUCCESSFULLY UPLOADED $successCount IMAGE(S)!',
              type: NotificationType.success,
            );
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 260,
          child: _buildGalleryGrid(
            context,
            roll,
            triple,
            shrinkWrap: true,
            emptyStateTopLeft: true,
            onEmptyStateTap: () => _handleImagesAddition(),
          ),
        ),
      ],
    );
  }

  Widget _buildLabImportBody(BuildContext context, Roll roll, RollGalleryTriple triple) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        if (triple.$1.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'UPLOADED IMAGES',
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

    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
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
              shot.aperture != null ? 'f/${shot.aperture}' : '---',
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onNextStatusTapped(BuildContext context) async {
    final rollAsync = ref.read(rollDetailProvider(widget.rollId));
    final roll = rollAsync.asData?.value;
    if (roll == null) return;

    final current = roll.status;
    if (current == RollStatus.archived) return;
    if (current == RollStatus.syncing) return;

    const userFlow = [
      RollStatus.shooting,
      RollStatus.lab,
      RollStatus.scanned,
      RollStatus.archived,
    ];
    final idx = userFlow.indexOf(current);
    if (idx < 0) return;
    final next = idx < userFlow.length - 1 ? userFlow[idx + 1] : RollStatus.archived;
    await _onStatusSelected(context, next);
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
          'WE COULDN\'T UPDATE THE STATUS. PLEASE TRY AGAIN.',
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
                'TECHNICAL DATA (${shots.length})',
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
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'No technical logs recorded for this roll.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
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
                                shot.aperture != null ? 'f/${shot.aperture}' : '---',
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
    final Color bg;
    final Color fg;

    switch (status) {
      case RollStatus.shooting:
        bg = Colors.orange.withOpacity(0.16);
        fg = Colors.orange;
        break;
      case RollStatus.lab:
        bg = Colors.blue.withOpacity(0.16);
        fg = Colors.blue;
        break;
      case RollStatus.scanned:
        bg = Colors.green.withOpacity(0.16);
        fg = Colors.green;
        break;
      case RollStatus.syncing:
        bg = Colors.blue.withOpacity(0.12);
        fg = Colors.blue.shade300;
        break;
      case RollStatus.archived:
        bg = Colors.grey.withOpacity(0.22);
        fg = Colors.grey.shade300;
        break;
    }

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
              status.label.toUpperCase(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ROLL INFO',
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
            labelText: 'Title',
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
            labelText: 'Description',
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
                          'ROLL INFO UPDATED!',
                          type: NotificationType.success,
                        );
                      }
                    } catch (e) {
                        ref.read(notificationProvider.notifier).show(
                          'WE COULDN\'T UPDATE YOUR ROLL INFO.',
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
                : const Text(
                    'SAVE',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
          ),
        ),
      ],
    );
  }
}

enum _LabImportMode { manual, drive }

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
        'SAVED $count PHOTO(S) ON THIS DEVICE.',
        type: NotificationType.success,
      );
    }
  }

  Future<void> _fetchLeafFiles() async {
    final url = _driveUrlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please paste a shared Drive URL (folder or ZIP).');
      return;
    }

    final user = ref.read(userProvider);
    if (user == null) {
      setState(() => _error = 'You must be signed in to sync from Drive.');
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
            'TRYING CLOUD SYNC…',
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

    if (_isDriveFolderUrl(url) && ref.read(userPlanProvider) == UserPlan.free) {
      try {
        final count = await AuthenticatedDriveFolderImportService.importFolder(
          api: _api,
          rollId: widget.rollId,
          folderUrl: url,
        );
        if (!mounted) return;
        await _afterLocalLabImport(count);
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = e.toString());
        ref.read(notificationProvider.notifier).show(
              'COULDN\'T IMPORT FOLDER ON DEVICE. CHECK DRIVE ACCESS.',
              type: NotificationType.error,
            );
        return;
      } finally {
        if (mounted) {
          setState(() => _isFetching = false);
        }
      }
    }

    // ZIP URLs cannot be pre-listed at leaf level reliably, so we directly sync (Plus/Pro cloud only).
    if (_isDriveZipUrl(url) && !_isDriveFolderUrl(url)) {
      try {
        if (!mounted) return;
        ref.read(notificationProvider.notifier).show(
          'ZIP DETECTED. EXTRACTING AND SYNCING PHOTOS...',
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
          _error = 'Unexpected response from Drive.';
        }
      } else {
        // If it's not clearly a folder or zip, just fall back to sync via auto-router.
        _leafFiles = const [];
      }

      if (!mounted) return;
      debugPrint('[Drive] auto-sync starting (leafFiles=${_leafFiles.length})');
      if (_isDriveFolderUrl(url)) {
        ref.read(notificationProvider.notifier).show(
          'FOUND ${_leafFiles.length} PHOTOS. IMPORTING INTO ROLL...',
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
            ? 'Backend error${status != null ? ' ($status)' : ''}: $detail'
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
          'SUCCESSFULLY IMPORTED $synced NEW PHOTOS!',
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
        'SYNC FAILED. PLEASE VERIFY YOUR DRIVE LINK AND PERMISSIONS.',
        type: NotificationType.error,
      );
    } catch (e) {
      ref.read(notificationProvider.notifier).show(
        'SOMETHING WENT WRONG DURING SYNC.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'IMPORT OPTIONS',
          style: TextStyle(
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
              label: const Text('Manual Add (Free)'),
              selected: _mode == _LabImportMode.manual,
              onSelected: (_) => setState(() => _mode = _LabImportMode.manual),
            ),
            if (!_manualUploadDone) ...[
              ChoiceChip(
                label: const Text('Drive URL (Plus)'),
                selected: _mode == _LabImportMode.drive,
                onSelected: (_) => setState(() => _mode = _LabImportMode.drive),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        if (_mode == _LabImportMode.manual)
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
              labelText: 'Shared Drive URL (folder or ZIP)',
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
                  : const Text(
                      'Fetch Files',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
              'Found ${_leafFiles.length} file(s) at leaf level.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.tune_rounded, size: 14, color: Colors.orange),
            const SizedBox(width: 8),
            const Text(
              'ALIGNMENT CALIBRATION',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w900,
                color: Colors.orange,
              ),
            ),
            const Spacer(),
            Text(
              '${_localOffset.toInt()} frames offset',
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Adjust if your scans start with blank loading frames.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
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
