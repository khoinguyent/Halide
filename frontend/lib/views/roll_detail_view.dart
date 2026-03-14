import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import '../core/widgets/glass_panel.dart';
import '../models/roll.dart';
import '../models/roll_status.dart';
import '../providers/auth_provider.dart';
import '../providers/roll_provider.dart';
import '../widgets/status_selector.dart';
import '../widgets/image_uploader_widget.dart';

class RollDetailView extends ConsumerWidget {
  final String rollId;

  const RollDetailView({Key? key, required this.rollId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rollAsync = ref.watch(rollDetailProvider(rollId));

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
                  onPressed: () => ref.refresh(rollDetailProvider(rollId)),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (roll) => _RollDetailBody(
        rollId: rollId,
        roll: roll,
        onRefresh: () => ref.refresh(rollDetailProvider(rollId)),
      ),
    );
  }
}

class _RollDetailBody extends ConsumerWidget {
  final String rollId;
  final Roll roll;
  final VoidCallback onRefresh;

  const _RollDetailBody({
    required this.rollId,
    required this.roll,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: Text(
          '${roll.brand} ${roll.name}',
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
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
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {
              showHalideModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => StatusSelector(
                  currentStatus: roll.status,
                  onStatusSelected: (s) => _onStatusSelected(context, ref, s),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassPanel(
              padding: const EdgeInsets.all(20),
              child: ImageUploaderWidget(
                rollId: rollId,
                onUploadComplete: onRefresh,
                darkMode: true,
              ),
            ),
            if (roll.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'UPLOADED IMAGES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.white.withOpacity(0.5),
                ),
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

  Future<void> _onStatusSelected(BuildContext context, WidgetRef ref, RollStatus newStatus) async {
    final rollService = ref.read(rollServiceProvider);
    final user = ref.read(userProvider);
    if (user == null) return;
    final token = await user.getIdToken();
    if (token == null) return;
    try {
      await rollService.updateRollStatus(token, rollId, newStatus.name);
      onRefresh();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    }
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
                    color: active ? Colors.white.withOpacity(0.8) : Colors.white.withOpacity(0.2),
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
