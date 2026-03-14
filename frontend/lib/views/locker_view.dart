import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/glass_panel.dart';
import '../providers/gear_provider.dart';
import '../models/camera.dart';
import '../models/lens.dart';

class LockerView extends ConsumerWidget {
  const LockerView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gearAsync = ref.watch(userGearProvider);

    return HalideScaffold(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                'THE GEARS',
                style: TextStyle(
                  letterSpacing: 4,
                  fontWeight: FontWeight.w200,
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
              centerTitle: false,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            sliver: gearAsync.when(
              data: (cameras) => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final camera = cameras[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _GearCard(camera: camera),
                    );
                  },
                  childCount: cameras.length,
                ),
              ),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Colors.white24)),
              ),
              error: (err, stack) => SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Error: $err',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GearCard extends StatelessWidget {
  final Camera camera;

  const _GearCard({
    Key? key,
    required this.camera,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
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
                    child: camera.imageUrl != null
                        ? Image.network(
                            camera.imageUrl!,
                            fit: BoxFit.cover,
                            width: 56,
                            height: 56,
                            errorBuilder: (_, __, ___) => const Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 28),
                          )
                        : const Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 28),
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
      ),
    );
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
