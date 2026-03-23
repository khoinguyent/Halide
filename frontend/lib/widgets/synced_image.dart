import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/widgets/image_placeholder.dart';

class SyncedImage extends StatelessWidget {
  final String rollId;
  final String imageUrl;
  final BoxFit fit;

  const SyncedImage({
    Key? key,
    required this.rollId,
    required this.imageUrl,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  Future<String?> _getLocalPath() async {
    if (imageUrl.startsWith('/') || imageUrl.startsWith('file://')) {
      return imageUrl;
    }
    if (!imageUrl.startsWith('http')) return null;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(Uri.parse(imageUrl).path);
      if (fileName.isEmpty) return null;

      final localPath = p.join(docDir.path, 'scans', rollId, fileName);
      final file = File(localPath);
      if (await file.exists()) {
        return localPath;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getLocalPath(),
      builder: (context, snapshot) {
        final path = snapshot.data;
        
        if (path != null && path.startsWith('/')) {
          return Image.file(
            File(path),
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildNetworkImage(),
          );
        }

        return _buildNetworkImage();
      },
    );
  }

  Widget _buildNetworkImage() {
    if (!imageUrl.startsWith('http')) {
      return const HalideImagePlaceholder();
    }
    
    // For cloud images, we try the thumb first if it's a known pattern.
    final thumbUrl = imageUrl.endsWith('.jpg') ? imageUrl.replaceFirst('.jpg', '_thumb.jpg') : imageUrl;

    return Image.network(
      thumbUrl,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Image.network(
          imageUrl,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => const HalideImagePlaceholder(),
        );
      },
    );
  }
}
