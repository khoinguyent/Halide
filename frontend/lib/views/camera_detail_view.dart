import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/widgets/glass_panel.dart';
import '../models/camera.dart';
import '../models/gear_status.dart';
import '../providers/gear_provider.dart';
import '../services/upload_service.dart';

class CameraDetailView extends ConsumerWidget {
  final String cameraId;

  const CameraDetailView({Key? key, required this.cameraId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camera = ref.watch(cameraProvider(cameraId));

    if (camera == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Center(child: Text('Camera not found', style: TextStyle(color: Colors.white.withOpacity(0.8)))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: Text(
          '${camera.brand} ${camera.model}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (modalContext) {
                  final bottomInset = MediaQuery.of(modalContext).padding.bottom;
                  const navBarHeight = 88.0;
                  final maxSheetHeight = MediaQuery.of(modalContext).size.height - bottomInset - navBarHeight;
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxSheetHeight),
                    child: _EditGearSheet(
                      camera: camera,
                      onSave: (nickname, brand, model, serialNumber, format, status) {
                        ref.read(userGearProvider.notifier).updateCameraDetails(cameraId,
                          nickname: nickname,
                          brand: brand,
                          model: model,
                          serialNumber: serialNumber.isEmpty ? null : serialNumber,
                          format: format.isEmpty ? null : format,
                          status: status,
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Information panel: Nickname, Brand, Model in one GlassPanel
            GlassPanel(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NICKNAME',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    camera.nickname.isEmpty ? '—' : camera.nickname,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BRAND',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              camera.brand,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MODEL',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              camera.model,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // GEAR IMAGES section: all uploaded images + edit action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'GEAR IMAGES',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${camera.imageUrls.length} / 3',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () => _showGearImagesEditSheet(
                        context,
                        ref,
                        cameraId: cameraId,
                        currentUrls: camera.imageUrls,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                      label: const Text('Edit', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlassPanel(
              padding: const EdgeInsets.all(16),
              child: camera.imageUrls.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library_outlined, size: 40, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(height: 8),
                            Text(
                              'No gear images yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap Edit to add up to 3 photos',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: camera.imageUrls.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        final path = camera.imageUrls[index];
                        final isLocal = path.startsWith('/') || path.startsWith(RegExp(r'^[A-Za-z]:'));
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: isLocal
                              ? Image.file(File(path), fit: BoxFit.cover)
                              : Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: Colors.white.withOpacity(0.5))),
                        );
                      },
                    ),
            ),
            // LINKED LENSES full-width section
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'LINKED LENSES',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                Text(
                  '+ LINK LENS',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlassPanel(
              padding: const EdgeInsets.all(20),
              child: camera.lenses.isEmpty
                  ? Row(
                      children: [
                        Icon(
                          Icons.lens_outlined,
                          size: 28,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'No lenses currently linked to this body',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: camera.lenses.map((lens) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.lens_outlined, color: Colors.white.withOpacity(0.4), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${lens.brand} ${lens.model}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (lens.nickname.isNotEmpty)
                                    Text(
                                      lens.nickname,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showGearImagesEditSheet(
    BuildContext context,
    WidgetRef ref, {
    required String cameraId,
    required List<String> currentUrls,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const navBarHeight = 88.0;
    final maxHeight = MediaQuery.of(context).size.height - bottomInset - navBarHeight;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: _GearImagesEditSheet(
          cameraId: cameraId,
          initialUrls: List<String>.from(currentUrls),
          onSave: (List<String> urls) {
            ref.read(userGearProvider.notifier).setCameraImages(cameraId, urls);
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }
}

// ─── Gear Images Edit Sheet ────────────────────────────────────────────────────

class _GearImagesEditSheet extends StatefulWidget {
  final String cameraId;
  final List<String> initialUrls;
  final void Function(List<String> urls) onSave;

  const _GearImagesEditSheet({
    required this.cameraId,
    required this.initialUrls,
    required this.onSave,
  });

  @override
  State<_GearImagesEditSheet> createState() => _GearImagesEditSheetState();
}

class _GearImagesEditSheetState extends State<_GearImagesEditSheet> {
  late List<String> _urls;
  final List<XFile> _pendingAdds = [];
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _urls = List<String>.from(widget.initialUrls);
  }

  int get _totalCount => _urls.length + _pendingAdds.length;
  static const int _maxImages = 3;

  Future<void> _pickMore() async {
    final remaining = _maxImages - _totalCount;
    if (remaining <= 0) return;
    final files = await _picker.pickMultiImage();
    if (files.isEmpty) return;
    setState(() {
      for (final f in files.take(remaining)) {
        if (_pendingAdds.length + _urls.length < _maxImages) _pendingAdds.add(f);
      }
    });
  }

  void _removeUrl(int index) {
    setState(() => _urls.removeAt(index));
  }

  void _removePending(int index) {
    setState(() => _pendingAdds.removeAt(index));
  }

  Future<void> _save() async {
    if (_pendingAdds.isEmpty) {
      widget.onSave(_urls);
      return;
    }
    setState(() => _isUploading = true);
    final uploadService = UploadService();
    final newPaths = <String>[];
    for (final xFile in _pendingAdds) {
      final ok = await uploadService.uploadRollImage(
        rollId: 'gear_${widget.cameraId}',
        imageFile: File(xFile.path),
      );
      if (ok) newPaths.add(xFile.path);
    }
    setState(() => _isUploading = false);
    if (!mounted) return;
    widget.onSave([..._urls, ...newPaths]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Edit gear images', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(
                  '$_totalCount / $_maxImages',
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _urls.length + _pendingAdds.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      if (index < _urls.length) {
                        final path = _urls[index];
                        final isLocal = path.startsWith('/') || path.startsWith(RegExp(r'^[A-Za-z]:'));
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: isLocal
                                  ? Image.file(File(path), fit: BoxFit.cover)
                                  : Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: Colors.white54)),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeUrl(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 18, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      final pendingIndex = index - _urls.length;
                      final xFile = _pendingAdds[pendingIndex];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(xFile.path), fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removePending(pendingIndex),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (_totalCount < _maxImages) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickMore,
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 22),
                      label: Text('Add photos (${_maxImages - _totalCount} left)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isUploading ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isUploading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashed glass panel (kept for potential reuse) ──────────────────────────────

class _DashedGlassPanel extends StatelessWidget {
  final Widget child;

  const _DashedGlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    const radius = 24.0;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.12),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(radius),
              ),
              child: child,
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: Colors.white.withOpacity(0.3),
              strokeWidth: 1.5,
              borderRadius: radius,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;
  static const double _dashWidth = 8;
  static const double _dashSpace = 4;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.borderRadius = 24,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);
    _drawDashedPath(canvas, path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final nextDistance = distance + _dashWidth;
        final extractPath = metric.extractPath(distance, nextDistance.clamp(0, metric.length));
        canvas.drawPath(extractPath, paint);
        distance = nextDistance + _dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Edit Gear Sheet ──────────────────────────────────────────────────────────

typedef _EditGearSave = void Function(
  String nickname,
  String brand,
  String model,
  String serialNumber,
  String format,
  GearStatus status,
);

class _EditGearSheet extends StatefulWidget {
  final Camera camera;
  final _EditGearSave onSave;

  const _EditGearSheet({required this.camera, required this.onSave});

  @override
  State<_EditGearSheet> createState() => _EditGearSheetState();
}

class _EditGearSheetState extends State<_EditGearSheet> {
  late TextEditingController _nicknameController;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _serialController;
  late TextEditingController _formatController;
  late GearStatus _status;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.camera.nickname);
    _brandController = TextEditingController(text: widget.camera.brand);
    _modelController = TextEditingController(text: widget.camera.model);
    _serialController = TextEditingController(text: widget.camera.serialNumber ?? '');
    _formatController = TextEditingController(text: widget.camera.format ?? '');
    _status = widget.camera.status;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _formatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reserve space so save button stays above bottom nav bar (match nav bar height used in showModalBottomSheet)
    const navBarHeight = 88.0;
    final bottomPadding = MediaQuery.of(context).padding.bottom + navBarHeight;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Edit gear', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomPadding),
                  children: [
                    _editField('Nickname', _nicknameController),
                    _editField('Brand', _brandController),
                    _editField('Model', _modelController),
                    _editField('Serial number', _serialController, optional: true),
                    _editField('Format', _formatController, optional: true),
                    const SizedBox(height: 16),
                    Text('Status', style: TextStyle(fontSize: 12, letterSpacing: 1, color: Colors.white.withOpacity(0.6))),
                    const SizedBox(height: 8),
                    ...GearStatus.values.map((s) => RadioListTile<GearStatus>(
                      title: Text(s.label, style: const TextStyle(color: Colors.white)),
                      value: s,
                      groupValue: _status,
                      onChanged: (v) => setState(() => _status = v!),
                      activeColor: Colors.white,
                    )),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          widget.onSave(
                            _nicknameController.text.trim(),
                            _brandController.text.trim(),
                            _modelController.text.trim(),
                            _serialController.text.trim(),
                            _formatController.text.trim(),
                            _status,
                          );
                          Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text('Save changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _editField(String label, TextEditingController controller, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, letterSpacing: 1, color: Colors.white.withOpacity(0.6))),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: optional ? 'Optional' : null,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

