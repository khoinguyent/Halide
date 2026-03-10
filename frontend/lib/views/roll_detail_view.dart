import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/roll_status.dart';
import '../providers/roll_provider.dart';
import '../widgets/status_selector.dart';
import '../widgets/image_uploader_widget.dart';

class RollDetailView extends ConsumerWidget {
  final String rollId;

  const RollDetailView({Key? key, required this.rollId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roll = ref.watch(rollProvider(rollId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          '${roll.brand} ${roll.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _StatusProgressBar(current: roll.status),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => StatusSelector(
                  currentStatus: roll.status,
                  onStatusSelected: (s) =>
                      ref.read(rollProvider(rollId).notifier).updateStatus(s),
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
                child: ImageUploaderWidget(rollId: rollId),
              ),
            ),

            // Uploaded images grid
            if (roll.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Uploaded Images',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: roll.imageUrls.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final path = roll.imageUrls[index];
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
          ],
        ),
      ),
    );
  }
}

// ─── Status Progress Bar ──────────────────────────────────────────────────────

class _StatusProgressBar extends StatelessWidget {
  final RollStatus current;
  const _StatusProgressBar({required this.current});

  @override
  Widget build(BuildContext context) {
    final steps = RollStatus.values;
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
