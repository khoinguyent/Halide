import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/gear_status.dart';
import '../providers/gear_provider.dart';
import '../widgets/gear_status_selector.dart';
import '../widgets/gear_image_uploader_widget.dart';

class CameraDetailView extends ConsumerWidget {
  final String cameraId;

  const CameraDetailView({Key? key, required this.cameraId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camera = ref.watch(cameraProvider(cameraId));

    if (camera == null) {
      return const Scaffold(
        body: Center(child: Text('Camera not found')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          '${camera.brand} ${camera.model}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _GearStatusProgressBar(current: camera.status),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => GearStatusSelector(
                  currentStatus: camera.status,
                  onStatusSelected: (s) =>
                      ref.read(userGearProvider.notifier).updateCameraStatus(cameraId, s),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Uploader card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GearImageUploaderWidget(
                  cameraId: cameraId,
                  currentImageCount: camera.imageUrls.length,
                ),
              ),
            ),

            // Uploaded images grid
            if (camera.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Uploaded Images',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: camera.imageUrls.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final path = camera.imageUrls[index];
                  final isLocal = path.startsWith('/');
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: isLocal
                        ? Image.file(File(path), fit: BoxFit.cover)
                        : Image.network(path, fit: BoxFit.cover),
                  );
                },
              ),
            ],
            
            // Lenses section
            if (camera.lenses.isNotEmpty) ...[
              const SizedBox(height: 24),
               const Text(
                'Mounted Lenses',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...camera.lenses.map((lens) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade100,
                    child: const Icon(Icons.trip_origin, color: Colors.black54),
                  ),
                  title: Text('${lens.brand} ${lens.model}'),
                  subtitle: Text(lens.nickname.isNotEmpty ? lens.nickname : 'No nickname'),
                ),
              )).toList(),
            ]
          ],
        ),
      ),
    );
  }
}

// ─── Status Progress Bar ──────────────────────────────────────────────────────

class _GearStatusProgressBar extends StatelessWidget {
  final GearStatus current;
  const _GearStatusProgressBar({required this.current});

  @override
  Widget build(BuildContext context) {
    final steps = GearStatus.values;
    final idx = steps.indexOf(current);

    return Row(
      children: steps.asMap().entries.map((e) {
        final active = e.key <= idx;
        final isLast = e.key == steps.length - 1;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: active ? Colors.black87 : Colors.grey.shade300,
                  ),
                ),
              ),
              if (!isLast) const SizedBox(width: 4),
            ],
          ),
        );
      }).toList(),
    );
  }
}
