import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/glass_panel.dart';
import '../providers/gear_provider.dart';
import '../models/camera.dart';
import '../models/gear_status.dart';
import '../models/lens.dart';
import '../widgets/gear_status_selector.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../core/utils/local_image_thumb.dart';

class LockerView extends ConsumerWidget {
  const LockerView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gearAsync = ref.watch(userGearProvider);

    return HalideScaffold(
      appBar: AppBar(
        title: const Text(
          'THE GEARS',
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white, size: 26),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add gear',
            onPressed: () => context.push('/locker/add-gear'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () async {
              await context.push('/profile');
              if (!context.mounted) return;
              ref.invalidate(userGearProvider);
            },
          ),
        ],
      ),
      child: gearAsync.when(
        data: (cameras) {
          if (cameras.isEmpty) {
            return _EmptyState(
              onAddFirstGear: () => context.push('/locker/add-gear'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(userGearProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: cameras.length,
              itemBuilder: (context, index) {
                final camera = cameras[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _GearCard(
                    camera: camera,
                    onStatusTap: (c) => _showGearStatusSheet(context, ref, c),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  'Error: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref.refresh(userGearProvider),
                  child: const Text('RETRY', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showGearStatusSheet(BuildContext context, WidgetRef ref, Camera camera) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        bool isPopping = false;
        return GearStatusSelector(
          currentStatus: camera.status,
          onStatusSelected: (s) {
            if (isPopping) return;
            isPopping = true;
            ref.read(userGearProvider.notifier).updateCameraStatus(camera.id, s);
            if (modalContext.mounted) {
              Navigator.of(modalContext).pop();
            }
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddFirstGear;

  const _EmptyState({Key? key, required this.onAddFirstGear}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white24),
              const SizedBox(height: 20),
              const Text(
                'No gear yet',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add your first camera or lens to start building your gear locker.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAddFirstGear,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ADD FIRST GEAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GearCard extends StatelessWidget {
  final Camera camera;
  final void Function(Camera camera)? onStatusTap;

  const _GearCard({
    Key? key,
    required this.camera,
    this.onStatusTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/locker/camera/${camera.id}'),
      child: GlassPanel(
        padding: EdgeInsets.zero,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Builder(
                      builder: (context) {
                        final url = camera.imageUrl;
                        if (url == null) return const Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 28);
                        
                        final isLocal = url.startsWith('/') || url.startsWith(RegExp(r'^[A-Za-z]:'));
                        if (isLocal) {
                          final px = localImageDecodeCacheExtent(context, 56);
                          return Image.file(
                            File(url),
                            fit: BoxFit.cover,
                            width: 56,
                            height: 56,
                            cacheWidth: px,
                            cacheHeight: px,
                            filterQuality: FilterQuality.low,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 28),
                          );
                        }
                        return Image.network(
                          url,
                          fit: BoxFit.cover,
                          width: 56,
                          height: 56,
                          errorBuilder: (_, __, ___) => const Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 28),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camera.nickname.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${camera.brand} ${camera.model}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (camera.serialNumber != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'S/N: ${camera.serialNumber}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 11,
                            fontFamily: 'Courier',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onStatusTap != null)
                  GestureDetector(
                    onTap: () => onStatusTap!(camera),
                    child: _GearStatusChip(status: camera.status),
                  ),
              ],
            ),
          ),
          if (camera.lenses.isNotEmpty) ...[
            Divider(color: Colors.white.withOpacity(0.05), height: 1),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MOUNTED LENSES',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...camera.lenses.map((lens) => _LensItem(lens: lens)).toList(),
                ],
              ),
            ),
          ],
        ],
      ), // closes Column
      ), // closes GlassPanel
    ); // closes GestureDetector
  }
}

class _LensItem extends StatelessWidget {
  final Lens lens;

  const _LensItem({Key? key, required this.lens}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.trip_origin, color: Colors.white.withOpacity(0.2), size: 12),
          const SizedBox(width: 12),
          Text(
            lens.nickname,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Text(
            '${lens.brand} ${lens.model}',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _GearStatusChip extends StatelessWidget {
  final GearStatus status;

  const _GearStatusChip({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case GearStatus.active:
        color = Colors.green;
        break;
      case GearStatus.repair:
        color = Colors.orange;
        break;
      case GearStatus.sold:
        color = Colors.grey;
        break;
      case GearStatus.archived:
        color = Colors.blueGrey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, color: color, size: 18),
        ],
      ),
    );
  }
}
