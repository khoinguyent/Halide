import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../services/upload_service.dart';
import '../core/widgets/image_placeholder.dart';
import '../core/providers/notification_provider.dart';
import '../core/models/notification_model.dart';

class ImageUploaderWidget extends ConsumerStatefulWidget {
  final String rollId;
  final VoidCallback? onUploadComplete;
  final bool darkMode;
  final bool readOnly;

  const ImageUploaderWidget({
    super.key,
    required this.rollId,
    this.onUploadComplete,
    this.darkMode = false,
    this.readOnly = false,
  });

  @override
  ConsumerState<ImageUploaderWidget> createState() =>
      _ImageUploaderWidgetState();
}

class _ImageUploaderWidgetState extends ConsumerState<ImageUploaderWidget> {
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  int _uploadedCount = 0;

  Future<void> _pickImages() async {
    if (widget.readOnly) return;
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  void _removeImage(int index) {
    if (widget.readOnly) return;
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _uploadImages() async {
    if (widget.readOnly) return;
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
    });

    final service = UploadService();
    final List<String> succeededPaths = [];

    for (final xFile in List.from(_selectedImages)) {
      final file = File(xFile.path);
      final success = await service.uploadRollImage(
        rollId: widget.rollId,
        imageFile: file,
      );
      if (success) {
        succeededPaths.add(xFile.path); // use local path as stand-in for URL
        setState(() => _uploadedCount++);
      }
    }

    if (succeededPaths.isNotEmpty) {
      widget.onUploadComplete?.call();
    }

    setState(() {
      _isUploading = false;
      _selectedImages.clear();
      _uploadedCount = 0;
    });

    if (mounted) {
      ref.read(notificationProvider.notifier).show(
        'Uploaded ${succeededPaths.length} image(s) successfully.',
        type: NotificationType.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _selectedImages.length;
    final fg = widget.darkMode ? Colors.white : Colors.black87;
    final fgMuted = widget.darkMode ? Colors.white.withOpacity(0.6) : Colors.grey.shade600;
    final borderColor = widget.darkMode ? Colors.white.withOpacity(0.2) : Colors.grey.shade300;
    final bgColor = widget.darkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50;

    if (widget.readOnly) {
      return Text(
        'Images are archived and can no longer be modified.',
        style: TextStyle(
          color: fgMuted,
          fontSize: 13,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add Images', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: fg)),
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
                  Text('Tap to select photos', style: TextStyle(color: fgMuted)),
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
                          errorBuilder: (context, error, stackTrace) {
                            return const HalideImagePlaceholder(
                              width: 120,
                              height: 120,
                              message: 'File missed',
                            );
                          },
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
              OutlinedButton(
                onPressed: _isUploading ? null : _pickImages,
                style: widget.darkMode ? OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)) : null,
                child: const Text('Add More'),
              ),
              const SizedBox(width: 8),
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
