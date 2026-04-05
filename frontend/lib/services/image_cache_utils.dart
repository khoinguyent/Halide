import 'dart:io';

import 'package:path/path.dart' as p;

/// Returns true if [file] is non-trivial size and starts with JPEG or PNG magic bytes.
Future<bool> isPlausibleImageCacheFile(File file) async {
  try {
    final len = await file.length();
    if (len < 32) return false;
    final raf = await file.open();
    try {
      final head = await raf.read(12);
      if (head.length < 3) return false;
      if (head[0] == 0xff && head[1] == 0xd8) return true;
      if (head.length >= 8 &&
          head[0] == 0x89 &&
          head[1] == 0x50 &&
          head[2] == 0x4e &&
          head[3] == 0x47) {
        return true;
      }
      return false;
    } finally {
      await raf.close();
    }
  } catch (_) {
    return false;
  }
}

/// Maps a full-resolution object URL to the companion thumbnail URL (R2 convention).
String thumbUrlForFullImageUrl(String fullUrl) {
  if (!fullUrl.startsWith('http')) return fullUrl;
  final lower = fullUrl.toLowerCase();
  if (lower.endsWith('.jpg')) {
    return fullUrl.replaceFirst(RegExp(r'\.jpg$', caseSensitive: false), '_thumb.jpg');
  }
  if (lower.endsWith('.jpeg')) {
    return fullUrl.replaceFirst(RegExp(r'\.jpeg$', caseSensitive: false), '_thumb.jpeg');
  }
  if (lower.endsWith('.png')) {
    return fullUrl.replaceFirst(RegExp(r'\.png$', caseSensitive: false), '_thumb.png');
  }
  return fullUrl;
}

String extensionFromImageUrl(String imageUrl) {
  var ext = p.extension(Uri.parse(imageUrl).path);
  if (ext.isEmpty || ext.length > 6) ext = '.jpg';
  return ext.toLowerCase();
}
