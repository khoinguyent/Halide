import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Detects the film-negative boundary in a light-table shot and returns
/// JPEG bytes cropped to that region (plus a small contextual border).
///
/// Falls back to the original bytes unchanged when:
/// - The image cannot be decoded.
/// - No film region is detected (all-white / all-dark frame).
/// - The detected region is implausibly small (< 10 % of each axis).
///
/// **Designed for [compute]** — pure Dart, no Flutter dependencies.
Uint8List autoCropNegative(Uint8List rawBytes) {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) return rawBytes;

  // Downsample to a working width for fast detection (~4-8× faster than
  // running on a 48 MP full-resolution image).
  const analyzeWidth = 1080;
  final scaleX = analyzeWidth / decoded.width;
  final small = img.copyResize(decoded, width: analyzeWidth);

  final bounds = _findNegativeBounds(small);
  if (bounds == null) return rawBytes;

  // Sanity: crop must cover at least 10 % on each axis.
  if (bounds.width < small.width * 0.10 ||
      bounds.height < small.height * 0.10) {
    return rawBytes;
  }

  // Scale detected bounds back to original resolution, then add a 2 % border
  // so we keep the film rebate (sprocket holes) in frame.
  final padX = (decoded.width * 0.02).round();
  final padY = (decoded.height * 0.02).round();
  final scaleY = scaleX; // uniform resize

  final x = (((bounds.left) / scaleX).round() - padX).clamp(0, decoded.width - 1);
  final y = (((bounds.top) / scaleY).round() - padY).clamp(0, decoded.height - 1);
  final r = (((bounds.left + bounds.width) / scaleX).round() + padX).clamp(x + 1, decoded.width);
  final b = (((bounds.top + bounds.height) / scaleY).round() + padY).clamp(y + 1, decoded.height);

  final w = r - x;
  final h = b - y;

  if (w < 100 || h < 100) return rawBytes;

  final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
  // Encode at high quality; this replaces the raw-capture JPEG.
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 93));
}

// ---------------------------------------------------------------------------
// Format-aware crop (used when a specific frame-guide box was shown).
// ---------------------------------------------------------------------------

/// Parameters for [autoCropNegativeForFormat], passed as a plain record so
/// [compute] can transfer the values across the isolate boundary.
typedef CropFormatParams = ({Uint8List bytes, double targetAspect});

/// Detects the film boundary (same as [autoCropNegative]) and then
/// centre-crops the result to [CropFormatParams.targetAspect] (width÷height).
///
/// This matches the aspect ratio of the on-screen frame-guide box, ensuring
/// the saved frame is exactly the intended film format.
///
/// **Designed for [compute]** — pure Dart, no Flutter dependencies.
Uint8List autoCropNegativeForFormat(CropFormatParams params) {
  // Step 1 — boundary detection crop (existing logic).
  final detected = autoCropNegative(params.bytes);

  final decoded = img.decodeImage(detected);
  if (decoded == null) return detected;

  final targetAspect = params.targetAspect;
  final srcW = decoded.width.toDouble();
  final srcH = decoded.height.toDouble();
  final srcAspect = srcW / srcH;

  // Tolerance: skip if already within 2 % of target.
  if ((srcAspect - targetAspect).abs() < 0.02) return detected;

  int x, y, w, h;
  if (srcAspect > targetAspect) {
    // Source is wider — trim left/right symmetrically.
    h = decoded.height;
    w = (h * targetAspect).round().clamp(1, decoded.width);
    x = ((decoded.width - w) / 2).round();
    y = 0;
  } else {
    // Source is taller — trim top/bottom symmetrically.
    w = decoded.width;
    h = (w / targetAspect).round().clamp(1, decoded.height);
    x = 0;
    y = ((decoded.height - h) / 2).round();
  }

  final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 93));
}

// ---------------------------------------------------------------------------
// Internal helpers — all pure functions, no state.
// ---------------------------------------------------------------------------

typedef _Bounds = ({int left, int top, int width, int height});

/// Finds the axis-aligned bounding box of the film negative within [image].
///
/// The detection is based on an adaptive brightness threshold derived from the
/// four corners of the image, which are almost certainly plain light-table
/// background.  Rows/columns are classified as "film" when at least
/// [_filmFraction] of their sampled pixels are darker than that threshold.
/// This fraction approach handles sparse sprocket-hole rows (mostly bright
/// transparent film, but surrounded by dark rebate) without false positives.
_Bounds? _findNegativeBounds(img.Image image) {
  const step = 4; // pixel stride for performance
  const filmFraction = 0.15; // ≥15 % dark pixels → row/col contains film

  final threshold = _cornerLuminance(image) * 0.88;

  int? top, bottom, left, right;

  // ── Top edge ──────────────────────────────────────────────────────────────
  for (var y = 0; y < image.height; y += step) {
    if (_rowFilmFraction(image, y, step, threshold) >= filmFraction) {
      top = y;
      break;
    }
  }
  if (top == null) return null; // no film at all

  // ── Bottom edge ───────────────────────────────────────────────────────────
  for (var y = image.height - 1; y > top; y -= step) {
    if (_rowFilmFraction(image, y, step, threshold) >= filmFraction) {
      bottom = y;
      break;
    }
  }
  if (bottom == null || bottom <= top) return null;

  // ── Left edge ─────────────────────────────────────────────────────────────
  for (var x = 0; x < image.width; x += step) {
    if (_colFilmFraction(image, x, step, threshold) >= filmFraction) {
      left = x;
      break;
    }
  }
  left ??= 0;

  // ── Right edge ────────────────────────────────────────────────────────────
  for (var x = image.width - 1; x > left; x -= step) {
    if (_colFilmFraction(image, x, step, threshold) >= filmFraction) {
      right = x;
      break;
    }
  }
  right ??= image.width - 1;

  final w = right - left;
  final h = bottom - top;
  if (w <= 0 || h <= 0) return null;

  return (left: left, top: top, width: w, height: h);
}

/// Average luminance of 4 corner blocks.
///
/// The corners are almost always pure light-table background, making them a
/// robust reference for the "white" level even when autoexposure adjusts the
/// overall brightness of the frame.
double _cornerLuminance(img.Image image) {
  final sz = (image.width * 0.04).round().clamp(10, 40);
  double sum = 0;
  int count = 0;

  for (final (int cx, int cy) in [
    (0, 0),
    (image.width - sz, 0),
    (0, image.height - sz),
    (image.width - sz, image.height - sz),
  ]) {
    for (var py = cy; py < cy + sz && py < image.height; py++) {
      for (var px = cx; px < cx + sz && px < image.width; px++) {
        sum += img.getLuminanceNormalized(image.getPixel(px, py));
        count++;
      }
    }
  }
  return count > 0 ? (sum / count) : 1.0;
}

double _rowFilmFraction(
    img.Image image, int y, int step, double threshold) {
  int film = 0, total = 0;
  for (var x = 0; x < image.width; x += step) {
    if (img.getLuminanceNormalized(image.getPixel(x, y)) < threshold) film++;
    total++;
  }
  return total > 0 ? film / total : 0;
}

double _colFilmFraction(
    img.Image image, int x, int step, double threshold) {
  int film = 0, total = 0;
  for (var y = 0; y < image.height; y += step) {
    if (img.getLuminanceNormalized(image.getPixel(x, y)) < threshold) film++;
    total++;
  }
  return total > 0 ? film / total : 0;
}
