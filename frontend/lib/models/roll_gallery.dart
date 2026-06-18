import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/image_cache_utils.dart';
import '../services/local_image_path_index.dart';
import 'roll.dart';
import 'shot.dart';

typedef RollGalleryTriple = (List<String> urls, List<String> imageIds, List<Shot> galleryShots);

/// Gallery [image_urls] entries are aligned with [shots] rows that carry an image key/URL.
/// Log-only shots (meter / EXIF) are excluded so indices stay in sync with thumbnails.
/// On-device lab imports use [LocalImagePathIndex] keys `lab:*` when the server sends no URLs.
class RollGalleryPairs {
  RollGalleryPairs._();

  static bool _isDisplayableAssetUrl(String? raw) {
    final u = (raw ?? '').trim();
    if (u.isEmpty) return false;
    return u.startsWith('http') ||
        u.startsWith('/') ||
        u.startsWith('file://');
  }

  /// Server [image_urls] aligned with shots that carry frames (no local lab merge).
  ///
  /// 1) Uses [Roll.imageUrls] when present (https / file / absolute paths).
  /// 2) If that list is empty, falls back to each [Shot.imageUrl] in frame order so
  ///    cloud URLs still load when the top-level array is empty but per-shot URLs exist.
  /// 3) If still empty, [tripleAsync] may use on-device lab imports.
  static RollGalleryTriple tripleServerOnly(Roll roll) {
    final urls = <String>[];
    for (final u in roll.imageUrls) {
      if (!_isDisplayableAssetUrl(u)) continue;
      urls.add(u.trim());
    }

    var urlsFromShotsOnly = false;
    if (urls.isEmpty) {
      urlsFromShotsOnly = true;
      final sortedShots = [...roll.shots]
        ..sort((a, b) => (a.frameNumber ?? 0).compareTo(b.frameNumber ?? 0));
      for (final s in sortedShots) {
        if (!_isDisplayableAssetUrl(s.imageUrl)) continue;
        urls.add(s.imageUrl!.trim());
      }
    }

    if (urls.isEmpty) {
      return ([], [], []);
    }

    if (urlsFromShotsOnly) {
      final ids = <String>[];
      final alignedShots = <Shot>[];
      final sortedShots = [...roll.shots]
        ..sort((a, b) => (a.frameNumber ?? 0).compareTo(b.frameNumber ?? 0));
      for (final s in sortedShots) {
        if (!_isDisplayableAssetUrl(s.imageUrl)) continue;
        ids.add(s.id);
        alignedShots.add(s);
      }
      return (urls, ids, alignedShots);
    }

    final shotsWithImage =
        roll.shots.where((s) => (s.imageUrl ?? '').trim().isNotEmpty).toList();
    final ids = <String>[];
    final alignedShots = <Shot>[];
    for (var i = 0; i < urls.length; i++) {
      if (i < shotsWithImage.length) {
        final s = shotsWithImage[i];
        alignedShots.add(s);
        ids.add(s.id);
      } else {
        final s = Shot(id: 'gallery:$i', rollId: roll.id, frameNumber: i);
        alignedShots.add(s);
        ids.add(s.id);
      }
    }
    return (urls, ids, alignedShots);
  }

  /// Prefer cloud/R2 URLs from the API ([imageUrls] or per-shot URLs); if none, gyro/lab files on device.
  static Future<RollGalleryTriple> tripleAsync(Roll roll) async {
    final server = tripleServerOnly(roll);
    if (server.$1.isNotEmpty) return server;
    final gyro = await _localGyroTriple(roll);
    if (gyro.$1.isNotEmpty) return gyro;
    return _localLabTriple(roll);
  }

  static Future<RollGalleryTriple> _localGyroTriple(Roll roll) async {
    final docDir = await getApplicationDocumentsDirectory();
    final entries = await LocalImagePathIndex.instance.listGyroEntriesSorted(roll.id);
    if (entries.isEmpty) {
      return (<String>[], <String>[], <Shot>[]);
    }

    final urls = <String>[];
    final ids = <String>[];
    for (final (_, key, rel) in entries) {
      final abs = p.isAbsolute(rel) ? rel : p.join(docDir.path, rel);
      final f = File(abs);
      if (!await f.exists()) continue;
      if (!await isPlausibleImageCacheFile(f)) continue;
      urls.add(abs);
      ids.add(key);
    }
    if (urls.isEmpty) {
      return (<String>[], <String>[], <Shot>[]);
    }

    final shots = _galleryShotsForCount(roll, urls.length);
    return (urls, ids, shots);
  }

  static Future<RollGalleryTriple> _localLabTriple(Roll roll) async {
    final docDir = await getApplicationDocumentsDirectory();
    final entries = await LocalImagePathIndex.instance.listLabEntriesSorted(roll.id);
    if (entries.isEmpty) {
      return (<String>[], <String>[], <Shot>[]);
    }

    final urls = <String>[];
    final ids = <String>[];
    for (final (_, key, rel) in entries) {
      final abs = p.isAbsolute(rel) ? rel : p.join(docDir.path, rel);
      final f = File(abs);
      if (!await f.exists()) continue;
      if (!await isPlausibleImageCacheFile(f)) continue;
      urls.add(abs);
      ids.add(key);
    }
    if (urls.isEmpty) {
      return (<String>[], <String>[], <Shot>[]);
    }

    final shots = _galleryShotsForCount(roll, urls.length);
    return (urls, ids, shots);
  }

  static List<Shot> _galleryShotsForCount(Roll roll, int n) {
    final sorted = [...roll.shots]
      ..sort((a, b) => (a.frameNumber ?? 0).compareTo(b.frameNumber ?? 0));
    final out = <Shot>[];
    for (var i = 0; i < n; i++) {
      if (i < sorted.length) {
        out.add(sorted[i]);
      } else {
        out.add(Shot(id: 'lab:$i', rollId: roll.id, frameNumber: i));
      }
    }
    return out;
  }
}
