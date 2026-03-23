import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/roll.dart';
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

class RollCard extends ConsumerStatefulWidget {
  final Roll roll;

  const RollCard({Key? key, required this.roll}) : super(key: key);

  @override
  ConsumerState<RollCard> createState() => _RollCardState();
}

class _RollCardState extends ConsumerState<RollCard> {
  final ApiService _api = ApiService();
  String? _fetchingRollId;

  Future<void> _handleFetchScans(String rollId, String driveUrl) async {
    debugPrint('Fetching from $driveUrl');
    if (!mounted) return;

    setState(() => _fetchingRollId = rollId);
    try {
      final resp = await _api.post(
        '/api/v1/storage/gdrive/sync_images_from_url',
        data: {
          'roll_id': rollId,
          'gdrive_url_or_id': driveUrl,
        },
      );

      if (!mounted) return;
      ref.invalidate(dashboardRollsProvider);
      ref.invalidate(rollDetailProvider(rollId));

      final data = resp.data;
      final synced = (data is Map && data['synced_count'] != null)
          ? data['synced_count'].toString()
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synced != null ? 'Imported $synced new image(s).'
              : 'Fetch completed.',
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final detail = data is Map && data['detail'] != null ? data['detail'].toString() : null;
      debugPrint('[RollCard] Fetch failed: status=${e.response?.statusCode} detail=$detail data=$data');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fetch failed: ${detail ?? e.message ?? e.toString()}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fetch failed: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _fetchingRollId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roll = widget.roll;

    final showLinkFetchAction =
        (roll.status == RollStatus.lab || roll.status == RollStatus.scanned) &&
            roll.imageUrls.isEmpty;
    final plan = ref.watch(userPlanProvider);
    final isFree = plan == UserPlan.free;

    final driveUrl = (roll.driveUrl ?? '').trim();
    final hasDriveUrl = driveUrl.isNotEmpty;

    return GlassPanel(
      padding: EdgeInsets.zero,
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
                      if (showLinkFetchAction && !isFree) ...[
                        const SizedBox(width: 10),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            // Important: this must not trigger the parent's gallery/roll navigation tap.
                            // The gesture is handled here, and the parent gesture should not fire.
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
                          child: _fetchingRollId == roll.id
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'SYNCING',
                                      style: TextStyle(
                                        color: Colors.blueAccent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.blueAccent,
                                        ),
                                      ),
                                    ),
                                  ],
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
    );
  }

  Widget _buildStateContent() {
    final roll = widget.roll;
    switch (roll.status) {
      case RollStatus.shooting:
        return _ShootingContent(maxFrames: roll.maxFrames);
      case RollStatus.lab:
        return _LabContent(maxFrames: roll.maxFrames);
      case RollStatus.scanned:
        return _ScannedContent(
          rollId: roll.id,
          imageUrls: roll.imageUrls,
          actualFrames: roll.imageUrls.length,
          totalFrames: roll.maxFrames,
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
            // Ensure the detail screen doesn't keep a stale cached roll status.
            ref.invalidate(rollDetailProvider(roll.id));
            return true;
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to update status')),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Link Drive URL',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              labelText: 'Drive URL (folder or ZIP)',
              labelStyle: const TextStyle(color: Colors.black54, fontSize: 13),
              filled: true,
              fillColor: Colors.grey.withOpacity(0.10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.black.withOpacity(0.10)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(color: Colors.blueAccent),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSaving
                ? null
                : () async {
                    final url = _controller.text.trim();
                    if (url.isEmpty) return;
                    setState(() => _isSaving = true);
                    debugPrint('Linking drive URL for roll=${widget.rollId}: $url');
                    try {
                      await _api.patch(
                        '/api/v1/rolls/${widget.rollId}/drive-url',
                        data: {'drive_url': url},
                      );
                      // Refresh any roll lists/details so the icon state updates.
                      ref.invalidate(dashboardRollsProvider);
                      ref.invalidate(rollDetailProvider(widget.rollId));
                      Navigator.of(context).pop();
                      // After saving, immediately trigger fetch (as requested).
                      await widget.onSavedFetch?.call(url);
                    } catch (e) {
                      if (!context.mounted) return;
                      setState(() => _isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save drive URL: $e')),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Not scanned: show total frames only (user input when creating roll).
class _ShootingContent extends StatelessWidget {
  final int maxFrames;

  const _ShootingContent({Key? key, required this.maxFrames}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        '$maxFrames Frames',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }
}

/// Not scanned: show total frames only.
class _LabContent extends StatelessWidget {
  final int maxFrames;

  const _LabContent({Key? key, required this.maxFrames}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        '$maxFrames Frames',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }
}

/// Scanned: show actual/total frames (e.g. 38/36 or 20/36).
class _ScannedContent extends StatelessWidget {
  final String rollId;
  final List<String> imageUrls;
  final int actualFrames;
  final int totalFrames;

  const _ScannedContent({
    Key? key,
    required this.rollId,
    required this.imageUrls,
    required this.actualFrames,
    required this.totalFrames,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Treat blank/empty URLs as "no preview images yet".
    // Also ignore non-displayable values (e.g. storage keys like users/.../x.jpg).
    final urls = imageUrls
        .where((u) => u.trim().isNotEmpty)
        .where((u) => u.startsWith('http') || u.startsWith('/'))
        .toList(growable: false);
    final effectiveActualFrames = urls.length;
    return Column(
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
                    fit: BoxFit.cover,
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
            onPressed: urls.isEmpty ? null : () => context.push('/roll/$rollId'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
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
    );
  }
}
