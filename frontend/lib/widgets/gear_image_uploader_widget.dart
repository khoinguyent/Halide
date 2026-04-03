import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
// Note: Ideally there would be a GearUploadService, using generic for now
import '../services/upload_service.dart';
import '../providers/gear_provider.dart';
import '../core/providers/notification_provider.dart';
import '../core/models/notification_model.dart';

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
  int _uploadedCount = 0;

  Future<void> _pickImages() async {
    final remainingSlots = widget.maxImages - (widget.currentImageCount + _selectedImages.length);
    if (remainingSlots <= 0) {
      ref.read(notificationProvider.notifier).show(
        'Maximum of ${widget.maxImages} images allowed per gear item.',
        type: NotificationType.error,
      );
      return;
    }

    final List<XFile> images = await _picker.pickMultiImage();
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

    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
    });

    final service = UploadService();
    final List<String> succeededPaths = [];

    for (final xFile in List.from(_selectedImages)) {
      final file = File(xFile.path);
      // Re-using uploadRollImage for MVP, in a real app this would be a gear specific endpoint
      final success = await service.uploadRollImage(
        rollId: 'gear_${widget.cameraId}',
        imageFile: file,
      );
      if (success) {
        succeededPaths.add(xFile.path); // use local path as stand-in for URL
        setState(() => _uploadedCount++);
      }
    }

    // Update the Gear's state with the new image URLs
    if (succeededPaths.isNotEmpty) {
      ref.read(userGearProvider.notifier).addCameraImages(widget.cameraId, succeededPaths);
    }

    setState(() {
      _isUploading = false;
      _selectedImages.clear();
      _uploadedCount = 0;
    });

    if (mounted) {
      ref.read(notificationProvider.notifier).show(
        'SUCCESSFULLY UPLOADED ${succeededPaths.length} IMAGE(S)!',
        type: NotificationType.success,
      );
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
              value: total > 0 ? _uploadedCount / total : null,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: widget.darkMode ? Colors.white.withOpacity(0.2) : null,
              valueColor: widget.darkMode ? const AlwaysStoppedAnimation<Color>(Colors.white) : null,
            ),
            const SizedBox(height: 8),
            Text('Uploading $_uploadedCount / $total...', style: TextStyle(color: fgMuted, fontSize: 13)),
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
