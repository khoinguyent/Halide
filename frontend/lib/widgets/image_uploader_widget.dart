import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../services/upload_service.dart';
import '../providers/roll_provider.dart';

class ImageUploaderWidget extends ConsumerStatefulWidget {
  final String rollId;

  const ImageUploaderWidget({super.key, required this.rollId});

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
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
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
      final success = await service.uploadRollImage(
        rollId: widget.rollId,
        imageFile: file,
      );
      if (success) {
        succeededPaths.add(xFile.path); // use local path as stand-in for URL
        setState(() => _uploadedCount++);
      }
    }

    // Update the Roll's state with the new image URLs
    if (succeededPaths.isNotEmpty) {
      ref.read(rollProvider(widget.rollId).notifier).addImages(succeededPaths);
    }

    setState(() {
      _isUploading = false;
      _selectedImages.clear();
      _uploadedCount = 0;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Uploaded ${succeededPaths.length} image(s) successfully.'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _selectedImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add Images',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                border: Border.all(color: Colors.grey.shade300, width: 2),
                color: Colors.grey.shade50,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text('Tap to select photos',
                      style: TextStyle(color: Colors.grey.shade500)),
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
            ),
            const SizedBox(height: 8),
            Text('Uploading $_uploadedCount / $total...',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              OutlinedButton(
                onPressed: _isUploading ? null : _pickImages,
                child: const Text('Add More'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
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
