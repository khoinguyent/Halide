import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/auth_provider.dart';
import '../providers/gear_provider.dart';
import '../services/gear_service.dart';
import '../core/providers/notification_provider.dart';
import '../core/models/notification_model.dart';
import '../core/utils/local_image_thumb.dart';
import '../core/constants/gear_image_upload.dart';

class GearImageUploaderWidget extends ConsumerStatefulWidget {
  final String cameraId;
  final int currentImageCount;
  final int maxImages;
  final bool darkMode;

  const GearImageUploaderWidget({
    super.key,
    required this.cameraId,
    required this.currentImageCount,
    this.maxImages = 3,
    this.darkMode = false,
  });

  @override
  ConsumerState<GearImageUploaderWidget> createState() =>
      _GearImageUploaderWidgetState();
}

class _GearImageUploaderWidgetState extends ConsumerState<GearImageUploaderWidget> {
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickImages() async {
    final remainingSlots = widget.maxImages - (widget.currentImageCount + _selectedImages.length);
    if (remainingSlots <= 0) {
      ref.read(notificationProvider.notifier).show(
        'Maximum of ${widget.maxImages} images allowed per gear item.',
        type: NotificationType.error,
      );
      return;
    }

    final List<XFile> images = await _picker.pickMultiImage(
      maxWidth: kGearImagePickerMaxDimension.toDouble(),
      maxHeight: kGearImagePickerMaxDimension.toDouble(),
      imageQuality: kGearImagePickerQuality,
      requestFullMetadata: false,
      limit: remainingSlots,
    );
    if (images.isNotEmpty) {
      // Enforce the constraint
      final imagesToAdd = images.take(remainingSlots).toList();
      setState(() {
        _selectedImages.addAll(imagesToAdd);
      });
      if (images.length > remainingSlots) {
        if (mounted) {
           ref.read(notificationProvider.notifier).show(
          'Only added $remainingSlots images to stay within the limit of ${widget.maxImages}.',
          type: NotificationType.info,
        );
        }
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty) return;

    setState(() => _isUploading = true);

    final user = ref.read(authServiceProvider).currentUser;
    final token = await user?.getIdToken();
    if (token == null) {
      if (mounted) {
        setState(() => _isUploading = false);
        ref.read(notificationProvider.notifier).show(
              'SIGN IN TO UPLOAD GEAR PHOTOS.',
              type: NotificationType.error,
            );
      }
      return;
    }

    final files = _selectedImages.map((x) => File(x.path)).toList();
    try {
      await ref.read(gearServiceProvider).uploadGearImages(token, widget.cameraId, files);
      if (!mounted) return;
      ref.invalidate(userGearProvider);
      ref.read(notificationProvider.notifier).show(
            'SUCCESSFULLY UPLOADED ${files.length} IMAGE(S)!',
            type: NotificationType.success,
          );
    } on GearImageUploadException catch (e, st) {
      debugPrint('[GearImageUploader] upload failed: $e\n$st');
      if (mounted) {
        final detail = e.detail?.toUpperCase() ?? '';
        String message = 'UPLOAD FAILED. CHECK CONNECTION OR STORAGE.';
        if (e.statusCode == 404 ||
            detail.contains('USER CAMERA NOT FOUND') ||
            detail.contains('NOT FOUND')) {
          message =
              'GEAR NOT FOUND FOR THIS ACCOUNT. OPEN THE LOCKER, PULL TO REFRESH, THEN TRY AGAIN.';
        } else if (e.statusCode == 402 || detail.contains('STORAGE LIMIT')) {
          message = 'STORAGE LIMIT REACHED. FREE SOME SPACE OR UPGRADE YOUR PLAN.';
        } else if (e.statusCode == 400) {
          message = detail.isNotEmpty ? detail : 'UPLOAD REJECTED. CHECK FILE SIZE (MAX 15 MB) AND FORMAT.';
        }
        ref.read(notificationProvider.notifier).show(message, type: NotificationType.error);
        ref.invalidate(userGearProvider);
      }
    } catch (e, st) {
      debugPrint('[GearImageUploader] upload failed: $e\n$st');
      if (mounted) {
        ref.read(notificationProvider.notifier).show(
              'UPLOAD FAILED. CHECK CONNECTION OR STORAGE.',
              type: NotificationType.error,
            );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _selectedImages.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _selectedImages.length;
    final remainingAllowed = widget.maxImages - widget.currentImageCount;

    if (remainingAllowed <= 0 && _selectedImages.isEmpty) {
      return const SizedBox.shrink(); // Hide uploader if max reached
    }

    final fg = widget.darkMode ? Colors.white : Colors.black87;
    final fgMuted = widget.darkMode ? Colors.white.withOpacity(0.6) : Colors.grey.shade600;
    final borderColor = widget.darkMode ? Colors.white.withOpacity(0.2) : Colors.grey.shade300;
    final bgColor = widget.darkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Add Images', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: fg)),
            Text('${widget.currentImageCount + _selectedImages.length} / ${widget.maxImages}', style: TextStyle(color: fgMuted)),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedImages.isEmpty)
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 2),
                color: bgColor,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 40, color: fgMuted),
                  const SizedBox(height: 8),
                  Text('Tap to select up to $remainingAllowed photos', style: TextStyle(color: fgMuted)),
                ],
              ),
            ),
          )
        else ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                final thumbPx = localImageDecodeCacheExtent(context, 120);
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_selectedImages[index].path),
                          height: 120,
                          width: 120,
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
                          onTap: _isUploading ? null : () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (_isUploading) ...[
            LinearProgressIndicator(
              borderRadius: BorderRadius.circular(4),
              backgroundColor: widget.darkMode ? Colors.white.withOpacity(0.2) : null,
              valueColor: widget.darkMode ? const AlwaysStoppedAnimation<Color>(Colors.white) : null,
            ),
            const SizedBox(height: 8),
            Text('Uploading…', style: TextStyle(color: fgMuted, fontSize: 13)),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              if (widget.currentImageCount + _selectedImages.length < widget.maxImages) ...[
                OutlinedButton(
                  onPressed: _isUploading ? null : _pickImages,
                  style: widget.darkMode ? OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)) : null,
                  child: const Text('Add More'),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                style: widget.darkMode ? ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), foregroundColor: Colors.white) : null,
                onPressed: _isUploading ? null : _uploadImages,
                icon: _isUploading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_isUploading ? 'Uploading...' : 'Upload All ($total)'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
