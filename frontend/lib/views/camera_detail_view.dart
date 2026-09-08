import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/l10n/enum_l10n.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import 'package:image_picker/image_picker.dart';
import '../core/widgets/glass_panel.dart';
import '../models/camera.dart';
import '../models/gear_status.dart';
import '../models/user_profile.dart';
import '../core/providers/notification_provider.dart';
import '../core/models/notification_model.dart';
import '../providers/gear_provider.dart';
import '../providers/auth_provider.dart';
import '../core/constants/free_tier_limits.dart';
import '../services/gear_service.dart';
import '../core/utils/local_image_thumb.dart';
import '../core/constants/gear_image_upload.dart';

class CameraDetailView extends ConsumerWidget {
  final String cameraId;

  const CameraDetailView({Key? key, required this.cameraId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camera = ref.watch(cameraProvider(cameraId));
    final l10n = context.l10n;
    final plan = ref.watch(userPlanProvider);

    if (camera == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Center(child: Text(l10n.cameraNotFound, style: TextStyle(color: Colors.white.withOpacity(0.8)))),
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
                useRootNavigator: true,
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
                        ref.read(userGearProvider.notifier).updateCameraDetails(camera.id,
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
                    l10n.nicknameLabel,
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
                              l10n.brandLabel,
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
                              l10n.modelLabel,
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
            // PHOTOS section: all uploaded images + edit action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.photo_library_outlined, size: 14, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(width: 8),
                    Text(
                      l10n.gallerySection,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.imageCount(camera.imageUrls.length, 3),
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
                        cameraId: camera.id,
                        currentUrls: camera.imageUrls,
                        plan: plan,
                      ),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18, color: Colors.white70),
                      label: Text(l10n.photos.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 11, letterSpacing: 1)),
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
              padding: const EdgeInsets.all(12),
              child: camera.imageUrls.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library_outlined, size: 32, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(height: 8),
                            Text(
                              l10n.noGearImagesYet,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: camera.imageUrls.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        final thumbPx = gearGalleryGridThumbCacheExtent(context);
                        final path = camera.imageUrls[index];
                        final isLocal = path.startsWith('/') || path.startsWith(RegExp(r'^[A-Za-z]:'));
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: isLocal
                              ? Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  cacheWidth: thumbPx,
                                  cacheHeight: thumbPx,
                                  filterQuality: FilterQuality.low,
                                )
                              : Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: Colors.white.withOpacity(0.5))),
                        );
                      },
                    ),
            ),
            // OPTICS section
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_tilt_shift, size: 14, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(width: 8),
                    Text(
                      l10n.opticsSection,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
                if (canMountLensOnCamera(plan, camera.lenses.length))
                  GestureDetector(
                  onTap: () => _showLinkLensSheet(context, ref, camera.id),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 16, color: Colors.white.withOpacity(0.5)),
                      const SizedBox(width: 6),
                      Text(
                        l10n.mountAction,
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlassPanel(
              padding: const EdgeInsets.all(12),
              child: camera.lenses.isEmpty
                  ? Row(
                      children: [
                        Icon(
                          Icons.lens_outlined,
                          size: 24,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.noOpticsMounted,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: camera.lenses.map((lens) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
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
                            IconButton(
                              icon: Icon(Icons.link_off, color: Colors.white.withOpacity(0.3), size: 18),
                              onPressed: () {
                                ref.read(userGearProvider.notifier).linkLens(lens.id, null);
                              },
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
    required UserPlan plan,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const navBarHeight = 88.0;
    final maxHeight = MediaQuery.of(context).size.height - bottomInset - navBarHeight;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: _GearImagesEditSheet(
          cameraId: cameraId,
          initialUrls: List<String>.from(currentUrls),
          plan: plan,
          onSave: (List<String> urls) {
            ref.read(userGearProvider.notifier).setCameraImages(cameraId, urls);
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  void _showLinkLensSheet(BuildContext context, WidgetRef ref, String cameraId) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return _LinkLensSheet(cameraId: cameraId);
      },
    );
  }

  static void _showCreateLensSheet(BuildContext context, WidgetRef ref, String cameraId) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateLensSheet(cameraId: cameraId),
    );
  }
}

// ─── Link Lens Sheet ──────────────────────────────────────────────────────────

class _LinkLensSheet extends ConsumerWidget {
  final String cameraId;

  const _LinkLensSheet({required this.cameraId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plan = ref.watch(userPlanProvider);
    final camera = ref.watch(cameraProvider(cameraId));
    final mountBlocked = camera != null && !canMountLensOnCamera(plan, camera.lenses.length);
    final lensesAsync = ref.watch(allUserLensesProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.selectLensToMount, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          if (mountBlocked) ...[
            const SizedBox(height: 12),
            Text(
              freeTierLensLimitMessage(),
              style: TextStyle(color: Colors.orange.shade300, fontSize: 13, height: 1.35),
            ),
          ],
          const SizedBox(height: 16),
          lensesAsync.when(
            data: (lenses) {
              final unlinked = lenses.where((l) => true).toList(); 
              return Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (unlinked.isEmpty)
                      Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(l10n.noLensesAvailable, style: const TextStyle(color: Colors.white54))))
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: unlinked.length,
                        itemBuilder: (ctx, index) {
                          final lens = unlinked[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${lens.brand} ${lens.model}', style: const TextStyle(color: Colors.white)),
                            subtitle: Text(lens.nickname, style: TextStyle(color: Colors.white.withOpacity(0.6))),
                            trailing: Icon(Icons.add_link, color: Colors.white.withOpacity(0.5)),
                            onTap: mountBlocked
                                ? null
                                : () {
                                    ref.read(userGearProvider.notifier).linkLens(lens.id, cameraId);
                                    Navigator.pop(ctx);
                                  },
                          );
                        },
                      ),
                    const Divider(color: Colors.white10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                      title: Text(l10n.createNewLensUpper, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13)),
                      onTap: mountBlocked
                          ? null
                          : () {
                              Navigator.pop(context);
                              CameraDetailView._showCreateLensSheet(context, ref, cameraId);
                            },
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, __) => Text(l10n.errorWithMessage(e.toString()), style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ─── Create Lens Sheet ────────────────────────────────────────────────────────

class _CreateLensSheet extends ConsumerStatefulWidget {
  final String cameraId;
  const _CreateLensSheet({required this.cameraId});

  @override
  ConsumerState<_CreateLensSheet> createState() => _CreateLensSheetState();
}

class _CreateLensSheetState extends ConsumerState<_CreateLensSheet> {
  final _nicknameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final nickname = _nicknameController.text.trim();
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();
    
    if (brand.isEmpty || model.isEmpty) {
      ref.read(notificationProvider.notifier).show(
        halideCaps(l10n.brandAndModelRequired),
        type: NotificationType.error,
      );
      return;
    }

    final mountBlock = ref.read(userGearProvider.notifier).blockReasonForMountLens(widget.cameraId);
    if (mountBlock != null) {
      ref.read(notificationProvider.notifier).show(
        mountBlock,
        type: NotificationType.warning,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(userGearProvider.notifier).addAndLinkLens({
        'gear_nickname': nickname.isEmpty ? '$brand $model' : nickname,
        'brand': brand,
        'model': model,
        'serial_number': _serialController.text.trim(),
      }, widget.cameraId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ref.read(notificationProvider.notifier).show(
          halideCaps(l10n.couldNotCreateLens),
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          Text(l10n.newLensDetails, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(l10n.createMountLensHint, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),
          _field(l10n.brandFieldHint, _brandController),
          _field(l10n.modelFieldHint, _modelController),
          _field(l10n.serialNumberOptional, _serialController),
          _field(l10n.nicknameFieldHint, _nicknameController),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : Text(l10n.createAndMount, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

// ─── Gear Images Edit Sheet ────────────────────────────────────────────────────

class _GearImagesEditSheet extends ConsumerStatefulWidget {
  final String cameraId;
  final List<String> initialUrls;
  final UserPlan plan;
  final void Function(List<String> urls) onSave;

  const _GearImagesEditSheet({
    required this.cameraId,
    required this.initialUrls,
    required this.plan,
    required this.onSave,
  });

  @override
  ConsumerState<_GearImagesEditSheet> createState() => _GearImagesEditSheetState();
}

class _GearImagesEditSheetState extends ConsumerState<_GearImagesEditSheet> {
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
    // Downscale at export time on iOS/Android — full-res HEIC/JPEG export is slow before we even paint.
    // requestFullMetadata: false avoids extra Photos work on iOS.
    final files = await _picker.pickMultiImage(
      maxWidth: kGearImagePickerMaxDimension.toDouble(),
      maxHeight: kGearImagePickerMaxDimension.toDouble(),
      imageQuality: kGearImagePickerQuality,
      requestFullMetadata: false,
      limit: remaining,
    );
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

    final l10n = context.l10n;
    setState(() => _isUploading = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      final token = await user?.getIdToken();
      if (token == null) {
        if (mounted) {
          ref.read(notificationProvider.notifier).show(
                halideCaps(l10n.signInSaveGearPhotos),
                type: NotificationType.error,
              );
        }
        return;
      }
      final files = _pendingAdds.map((x) => File(x.path)).toList();
      final updated = await ref.read(gearServiceProvider).uploadGearImages(token, widget.cameraId, files);
      final raw = updated['image_urls'];
      final fromServer = raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
      if (!mounted) return;
      widget.onSave(fromServer);
      ref.invalidate(userGearProvider);
    } on GearImageUploadException catch (e, st) {
      debugPrint('[GearImagesEditSheet] upload failed: $e\n$st');
      if (mounted) {
        final detail = e.detail?.toUpperCase() ?? '';
        String message = halideCaps(l10n.uploadFailedCheckConnection);
        if (e.statusCode == 404 ||
            detail.contains('USER CAMERA NOT FOUND') ||
            detail.contains('NOT FOUND')) {
          message = halideCaps(l10n.gearNotFoundRefresh);
        } else if (e.statusCode == 402 || detail.contains('STORAGE LIMIT')) {
          message = halideCaps(l10n.storageLimitFreeSpace);
        } else if (e.statusCode == 400) {
          message = detail.isNotEmpty ? detail : halideCaps(l10n.uploadRejectedFormat);
        }
        ref.read(notificationProvider.notifier).show(
              message,
              type: NotificationType.error,
            );
        ref.invalidate(userGearProvider);
      }
    } catch (e, st) {
      debugPrint('[GearImagesEditSheet] upload failed: $e\n$st');
      if (mounted) {
        ref.read(notificationProvider.notifier).show(
              halideCaps(l10n.uploadFailedCheckConnection),
              type: NotificationType.error,
            );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                Text(l10n.editGearImages, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(
                  l10n.imageCount(_totalCount, _maxImages),
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20, 
                0, 
                20, 
                24 + MediaQuery.of(context).padding.bottom + 88.0, // Push above floating nav bar (88px height)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Builder(
                    builder: (context) {
                      final thumbPx = gearGalleryGridThumbCacheExtent(context);
                      return GridView.builder(
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
                                  ? Image.file(
                                      File(path),
                                      fit: BoxFit.cover,
                                      cacheWidth: thumbPx,
                                      cacheHeight: thumbPx,
                                      filterQuality: FilterQuality.low,
                                    )
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
                            child: Image.file(
                              File(xFile.path),
                              fit: BoxFit.cover,
                              cacheWidth: thumbPx,
                              cacheHeight: thumbPx,
                              filterQuality: FilterQuality.low,
                            ),
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
                  );
                    },
                  ),
                  if (_totalCount < _maxImages) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickMore,
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 22),
                      label: Text(l10n.addPhotosLeft(_maxImages - _totalCount)),
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
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : Text(l10n.save),
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
  bool _isSaving = false;

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
    final l10n = context.l10n;
    const navBarHeight = 88.0;
    final bottomPadding = MediaQuery.of(context).padding.bottom + MediaQuery.of(context).viewInsets.bottom + navBarHeight;

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
                    Text(l10n.editGear, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomPadding),
                  children: [
                    _editField(l10n.nickname, _nicknameController),
                    _editField(l10n.manufacturer, _brandController),
                    _editField(l10n.model, _modelController),
                    _editField(l10n.serialNumber, _serialController, optional: true),
                    _editField(l10n.formatLabel, _formatController, optional: true),
                    const SizedBox(height: 16),
                    Text(l10n.status, style: TextStyle(fontSize: 12, letterSpacing: 1, color: Colors.white.withOpacity(0.6))),
                    const SizedBox(height: 8),
                    ...GearStatus.values.map((s) => RadioListTile<GearStatus>(
                      title: Text(s.localizedLabel(l10n), style: const TextStyle(color: Colors.white)),
                      value: s,
                      groupValue: _status,
                      onChanged: (v) => setState(() => _status = v!),
                      activeColor: Colors.white,
                    )),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSaving ? null : () {
                          setState(() => _isSaving = true);
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
                        child: _isSaving 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                          : Text(l10n.saveChanges),
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
    final l10n = context.l10n;
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
              hintText: optional ? l10n.optionalField : null,
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

