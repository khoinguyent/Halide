import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/roll.dart';
import '../models/roll_status.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/halide_dialog.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/roll_provider.dart';
import 'status_selector.dart';

class RollCard extends ConsumerWidget {
  final Roll roll;

  const RollCard({Key? key, required this.roll}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  Text(
                    _formatDate(roll.createdAt!),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
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
                      ? roll.title!.trim().toUpperCase()
                      : roll.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${roll.name.toUpperCase()} - ${roll.cameraName ?? "Unknown Camera"}${roll.lensName != null && roll.lensName!.trim().isNotEmpty ? " + ${roll.lensName!.trim()}" : ""}',
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
                  child: Image.network(
                    urls[index],
                    fit: BoxFit.cover,
                    width: 140,
                    height: 100,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.white.withOpacity(0.05),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      // If the specific URL is broken, render nothing.
                      // ignore: avoid_print
                      debugPrint('[RollCard] image preview failed url=${urls[index]} err=$error');
                      return const SizedBox.shrink();
                    },
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
