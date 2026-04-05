import 'shot.dart';
import 'roll.dart';

/// Gallery [image_urls] entries are aligned with [shots] rows that carry an image key/URL.
/// Log-only shots (meter / EXIF) are excluded so indices stay in sync with thumbnails.
class RollGalleryPairs {
  RollGalleryPairs._();

  /// Parallel lists: each URL matches the same index in [imageIds] and [shotsWithImage].
  static (List<String> urls, List<String> imageIds, List<Shot> shotsWithImage) triple(
    Roll roll,
  ) {
    final shotsWithImage =
        roll.shots.where((s) => (s.imageUrl ?? '').trim().isNotEmpty).toList();
    final urls = <String>[];
    final ids = <String>[];
    final alignedShots = <Shot>[];
    for (var i = 0; i < roll.imageUrls.length; i++) {
      final u = roll.imageUrls[i];
      if (u.trim().isEmpty) continue;
      if (!u.startsWith('http') && !u.startsWith('/') && !u.startsWith('file://')) {
        continue;
      }
      if (i >= shotsWithImage.length) break;
      urls.add(u);
      ids.add(shotsWithImage[i].id);
      alignedShots.add(shotsWithImage[i]);
    }
    return (urls, ids, alignedShots);
  }
}
