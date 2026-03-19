import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import '../core/widgets/glass_panel.dart';
import '../models/roll.dart';
import '../models/roll_status.dart';
import '../models/film_stock.dart';
import '../models/camera.dart';
import '../providers/auth_provider.dart';
import '../providers/roll_provider.dart';
import '../providers/rolls_provider.dart';
import '../features/rolls/presentation/bloc/rolls_bloc.dart';
import '../widgets/status_selector.dart';
import '../widgets/image_uploader_widget.dart';
import '../widgets/full_screen_viewer.dart';
import '../services/api_service.dart';

class RollDetailView extends ConsumerStatefulWidget {
  final String rollId;

  const RollDetailView({Key? key, required this.rollId}) : super(key: key);

  @override
  ConsumerState<RollDetailView> createState() => _RollDetailViewState();
}

class _RollDetailViewState extends ConsumerState<RollDetailView> {
  @override
  void initState() {
    super.initState();
    // Force refresh to avoid stale roll status (e.g. list shows Scanned
    // but detail still has cached Shooting).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(rollDetailProvider(widget.rollId));
    });
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
      data: (roll) => _RollDetailBody(
        rollId: widget.rollId,
        roll: roll,
        onRefresh: () => ref.refresh(rollDetailProvider(widget.rollId)),
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
    final isScanned = roll.status == RollStatus.scanned;
    final isArchived = roll.status == RollStatus.archived;
    final isShooting = roll.status == RollStatus.shooting;

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
              onTap: isShooting ? null : () => _onNextStatusTapped(context, ref),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isScanned
          ? _buildScannedBody(context, ref)
          : isArchived
              ? _buildGalleryGrid(context, roll)
              : isShooting
                  ? _buildShootingMetaEditor(context, ref)
                  : _buildLabImportBody(context, ref),
    );
  }

  /// For scanned rolls, show gallery when images exist; otherwise, keep the
  /// "No images yet" state and surface the same import options used for Lab.
  Widget _buildScannedBody(BuildContext context, WidgetRef ref) {
    final hasDisplayableImages = roll.imageUrls
        .where((u) => u.trim().isNotEmpty)
        .where((u) => u.startsWith('http') || u.startsWith('/'))
        .isNotEmpty;

    if (hasDisplayableImages) {
      return _buildGalleryGrid(context, roll);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 260,
            child: _buildGalleryGrid(context, roll),
          ),
          const SizedBox(height: 24),
          GlassPanel(
            padding: const EdgeInsets.all(20),
            child: _LabImportOptions(
              rollId: rollId,
              onUploadComplete: onRefresh,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabImportBody(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPanel(
            padding: const EdgeInsets.all(20),
            child: _LabImportOptions(
              rollId: rollId,
              onUploadComplete: onRefresh,
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
            _buildGalleryGrid(context, roll, shrinkWrap: true),
          ],
        ],
      ),
    );
  }

  Widget _buildGalleryGrid(BuildContext context, Roll roll, {bool shrinkWrap = false}) {
    final images = roll.imageUrls
        .where((u) => u.trim().isNotEmpty)
        // Only render displayable URLs. Backend may return storage keys (e.g. users/.../x.jpg)
        // that are not directly fetchable by the client.
        .where((u) => u.startsWith('http') || u.startsWith('/'))
        .toList(growable: false);
    if (images.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined, size: 48, color: Colors.white.withOpacity(0.25)),
              const SizedBox(height: 14),
              const Text(
                'No images yet',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'When scans are uploaded or synced from the lab, they’ll show up here.',
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13, height: 1.35),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
        final isLocal = path.startsWith('/');
        final isNetwork = path.startsWith('http');
        final thumbUrl = isNetwork && path.endsWith('.jpg')
            ? path.replaceFirst('.jpg', '_thumb.jpg')
            : path;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => FullScreenViewer(
                  imageUrls: images,
                  initialIndex: index,
                  iso: roll.shotAtIso,
                  dateScanned: roll.createdAt,
                  filmStock: FilmStock(id: roll.filmStockId, brand: roll.brand, name: roll.name, iso: roll.shotAtIso ?? 400, format: '135', colorType: 'Color'),
                  camera: Camera(id: roll.userCameraId, brand: roll.brand, model: roll.cameraName ?? 'Unknown', nickname: roll.nickname ?? ''),
                ),
              ),
            );
          },
          child: Hero(
            tag: path,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isNetwork
                  ? Image.network(
                      thumbUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback: if thumbnail missing, load original image.
                            // Log the failing URL so we can see whether it's a 403/404.
                            // ignore: avoid_print
                            debugPrint('[Gallery] thumb load failed url=$thumbUrl err=$error');
                        return Image.network(path, fit: BoxFit.cover);
                      },
                    )
                  : (isLocal ? Image.file(File(path), fit: BoxFit.cover) : Container(color: Colors.white10)),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onNextStatusTapped(BuildContext context, WidgetRef ref) async {
    final current = roll.status;
    if (current == RollStatus.archived) {
      // Archived is terminal; ignore tap.
      return;
    }
    final steps = RollStatus.values;
    final idx = steps.indexOf(current);
    final next = idx < steps.length - 1 ? steps[idx + 1] : RollStatus.archived;
    await _onStatusSelected(context, ref, next);
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

  Widget _buildShootingMetaEditor(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
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
                  rollId,
                  title: title,
                  description: description,
                );
                onRefresh();
              },
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
          ],
        ),
      ),
    );
  }
}

class _RollMetaEditor extends StatefulWidget {
  final String initialTitle;
  final String initialDescription;
  final Future<void> Function(String title, String description) onSave;

  const _RollMetaEditor({
    required this.initialTitle,
    required this.initialDescription,
    required this.onSave,
  });

  @override
  State<_RollMetaEditor> createState() => _RollMetaEditorState();
}

class _RollMetaEditorState extends State<_RollMetaEditor> {
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Roll info updated'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update: $e')),
                        );
                      }
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

    setState(() {
      _isFetching = true;
      _error = null;
      _leafFiles = const [];
    });

    // ZIP URLs cannot be pre-listed at leaf level reliably, so we directly sync.
    if (_isDriveZipUrl(url) && !_isDriveFolderUrl(url)) {
      try {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ZIP detected. Extracting images and syncing...')),
        );
        await _syncImagesFromUrl();
        return;
      } catch (_) {
        // Error handling happens inside _syncImagesFromUrl().
      }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${_leafFiles.length} file(s). Importing into roll...')),
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

  Future<void> _syncImagesFromUrl() async {
    try {
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
      final synced = (data is Map && data['synced_count'] != null)
          ? data['synced_count'].toString()
          : '0';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported $synced new image(s) into this roll.'),
        ),
      );
      widget.onUploadComplete();
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final detail =
          body is Map<String, dynamic> ? body['detail']?.toString() : body?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail != null && detail.isNotEmpty
                ? 'Sync failed${status != null ? ' ($status)' : ''}: $detail'
                : 'Sync failed: $e',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    }
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
            ChoiceChip(
              label: const Text('Drive URL (Pro)'),
              selected: _mode == _LabImportMode.drive,
              onSelected: (_) => setState(() => _mode = _LabImportMode.drive),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_mode == _LabImportMode.manual)
          ImageUploaderWidget(
            rollId: widget.rollId,
            onUploadComplete: widget.onUploadComplete,
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
