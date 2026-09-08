import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'gyro_scan_constants.dart';

/// Default gamma — matches [process_selective_inversion.py].
const double gyroScanInvertGamma = 1.10;

/// Isolate-safe single argument for [processGyroScanCapture].
typedef GyroScanProcessParams = ({
  Uint8List bytes,
  double cropTop,
  double cropLeft,
  double cropWidth,
  double cropHeight,
});

/// Worker-isolate entry: deterministic crop → C-41 inversion → JPEG.
Uint8List processGyroScanCapture(GyroScanProcessParams params) {
  return invertNegativeJpeg(
    params.bytes,
    top: params.cropTop,
    left: params.cropLeft,
    width: params.cropWidth,
    height: params.cropHeight,
  );
}

/// Full scan pipeline: optional normalized crop, then selective inversion.
///
/// [top], [left], [width], [height] are fractions of the decoded image size
/// (0.0–1.0). When all four are provided the image is cropped first.
img.Image applyC41Conversion(
  img.Image image, {
  double? top,
  double? left,
  double? width,
  double? height,
}) {
  final work = _cropNormalized(image, top: top, left: left, width: width, height: height);
  applySelectiveFilmInversion(work);
  return work;
}

/// Fast path for live preview — fixed matrix, no per-image stats.
void applyOrangeMaskInversion(img.Image image) {
  const m = orangeMaskPreviewMatrix;
  final rScale = m[0];  final rBias = m[4];
  final gScale = m[6];  final gBias = m[9];
  final bScale = m[12]; final bBias = m[14];

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final nr = (rScale * p.r + rBias).clamp(0, 255).round();
      final ng = (gScale * p.g + gBias).clamp(0, 255).round();
      final nb = (bScale * p.b + bBias).clamp(0, 255).round();
      image.setPixelRgba(x, y, nr, ng, nb, p.a);
    }
  }
}

/// Decode JPEG → optional normalized crop → C-41 pipeline → re-encode.
/// **Designed for [compute]** — pure Dart, no Flutter dependencies.
Uint8List invertNegativeJpeg(
  Uint8List jpegBytes, {
  double? top,
  double? left,
  double? width,
  double? height,
}) {
  final decoded = img.decodeImage(jpegBytes);
  if (decoded == null) return jpegBytes;
  final result = applyC41Conversion(
    decoded,
    top: top,
    left: left,
    width: width,
    height: height,
  );
  return Uint8List.fromList(img.encodeJpg(result, quality: 93));
}

// ---------------------------------------------------------------------------
// Selective inversion
// ---------------------------------------------------------------------------

/// C-41 inversion on a film-only image (expected after deterministic crop).
void applySelectiveFilmInversion(
  img.Image image, {
  double gamma = gyroScanInvertGamma,
  double stretchLoPct = 1.5,
  double stretchHiPct = 98.5,
}) {
  final w = image.width;
  final h = image.height;
  final n = w * h;

  // ── Step 1: strict float in [0, 1] ────────────────────────────────────────
  final rF = Float64List(n);
  final gF = Float64List(n);
  final bF = Float64List(n);
  var i = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      rF[i] = p.r / 255.0;
      gF[i] = p.g / 255.0;
      bF[i] = p.b / 255.0;
      i++;
    }
  }

  // ── Step 2: orange base (85th pct of border band) ─────────────────────────
  final base = _sampleOrangeBase85(image);

  // ── Steps 3+4: normalise → clip [0,1] → invert (strictly bounded) ────────
  final rI = Float64List(n);
  final gI = Float64List(n);
  final bI = Float64List(n);
  for (var j = 0; j < n; j++) {
    rI[j] = _invertChannel(rF[j], base.$1);
    gI[j] = _invertChannel(gF[j], base.$2);
    bI[j] = _invertChannel(bF[j], base.$3);
  }

  // ── Step 5: per-channel auto-levels ───────────────────────────────────────
  final loR = _percentile(rI, stretchLoPct);  final hiR = _percentile(rI, stretchHiPct);
  final loG = _percentile(gI, stretchLoPct);  final hiG = _percentile(gI, stretchHiPct);
  final loB = _percentile(bI, stretchLoPct);  final hiB = _percentile(bI, stretchHiPct);
  final spanR = math.max(hiR - loR, 1e-6);
  final spanG = math.max(hiG - loG, 1e-6);
  final spanB = math.max(hiB - loB, 1e-6);
  for (var j = 0; j < n; j++) {
    rI[j] = ((rI[j] - loR) / spanR).clamp(0.0, 1.0);
    gI[j] = ((gI[j] - loG) / spanG).clamp(0.0, 1.0);
    bI[j] = ((bI[j] - loB) / spanB).clamp(0.0, 1.0);
  }

  // ── Step 6: gamma ─────────────────────────────────────────────────────────
  for (var j = 0; j < n; j++) {
    rI[j] = math.pow(rI[j].clamp(0.0, 1.0), gamma).toDouble();
    gI[j] = math.pow(gI[j].clamp(0.0, 1.0), gamma).toDouble();
    bI[j] = math.pow(bI[j].clamp(0.0, 1.0), gamma).toDouble();
  }

  // ── Step 7: grey-world colour balance ─────────────────────────────────────
  final avgR = rI.reduce((a, b) => a + b) / n;
  final avgG = gI.reduce((a, b) => a + b) / n;
  final avgB = bI.reduce((a, b) => a + b) / n;
  final mean = (avgR + avgG + avgB) / 3.0;
  final gainR = (mean / math.max(avgR, 1e-6)).clamp(0.80, 1.20);
  final gainG = (mean / math.max(avgG, 1e-6)).clamp(0.80, 1.20);
  final gainB = (mean / math.max(avgB, 1e-6)).clamp(0.80, 1.20);
  for (var j = 0; j < n; j++) {
    rI[j] = (rI[j] * gainR).clamp(0.0, 1.0);
    gI[j] = (gI[j] * gainG).clamp(0.0, 1.0);
    bI[j] = (bI[j] * gainB).clamp(0.0, 1.0);
  }

  // ── Step 8: unsharp mask ──────────────────────────────────────────────────
  _unsharpMask(rI, gI, bI, w, h, amount: 0.45, radius: 1);

  // ── Write back ─────────────────────────────────────────────────────────────
  i = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      image.setPixelRgba(
        x, y,
        (rI[i] * 255).round().clamp(0, 255),
        (gI[i] * 255).round().clamp(0, 255),
        (bI[i] * 255).round().clamp(0, 255),
        p.a,
      );
      i++;
    }
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Crops [image] when all normalized bounds are provided; otherwise returns
/// [image] unchanged.
img.Image _cropNormalized(
  img.Image image, {
  double? top,
  double? left,
  double? width,
  double? height,
}) {
  if (top == null || left == null || width == null || height == null) {
    return image;
  }

  final x = (left.clamp(0.0, 1.0) * image.width).round().clamp(0, image.width - 1);
  final y = (top.clamp(0.0, 1.0) * image.height).round().clamp(0, image.height - 1);
  final w = (width.clamp(0.0, 1.0) * image.width).round().clamp(1, image.width - x);
  final h = (height.clamp(0.0, 1.0) * image.height).round().clamp(1, image.height - y);

  if (w < 8 || h < 8) return image;
  return img.copyCrop(image, x: x, y: y, width: w, height: h);
}

/// Divide by orange base, clip neutral density to [0, 1], then invert.
double _invertChannel(double channel, double orangeBase) {
  final safeBase = math.max(orangeBase, 1e-6);
  final neutral = (channel / safeBase).clamp(0.0, 1.0);
  return (1.0 - neutral).clamp(0.0, 1.0);
}

/// Orange base: 85th-percentile of the outer border band on the cropped frame.
(double, double, double) _sampleOrangeBase85(img.Image image) {
  final marginX = math.max((image.width * 0.04).round(), 2);
  final marginY = math.max((image.height * 0.04).round(), 2);

  final rs = <double>[];
  final gs = <double>[];
  final bs = <double>[];

  void samplePixel(int x, int y) {
    final p = image.getPixel(x, y);
    rs.add(p.r / 255.0);
    gs.add(p.g / 255.0);
    bs.add(p.b / 255.0);
  }

  for (var x = 0; x < image.width; x++) {
    for (var y = 0; y < marginY; y++) {
      samplePixel(x, y);
    }
    for (var y = image.height - marginY; y < image.height; y++) {
      samplePixel(x, y);
    }
  }
  for (var y = marginY; y < image.height - marginY; y++) {
    for (var x = 0; x < marginX; x++) {
      samplePixel(x, y);
    }
    for (var x = image.width - marginX; x < image.width; x++) {
      samplePixel(x, y);
    }
  }

  if (rs.isEmpty) return (0.161, 0.294, 0.702);
  return (
    math.max(_percentile(rs, 85), 1e-6),
    math.max(_percentile(gs, 85), 1e-6),
    math.max(_percentile(bs, 85), 1e-6),
  );
}

void _unsharpMask(
  Float64List r, Float64List g, Float64List b,
  int w, int h, {
  required double amount,
  required int radius,
}) {
  final orig = img.Image(width: w, height: h);
  var i = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      orig.setPixelRgba(x, y,
        (r[i]*255).round().clamp(0,255),
        (g[i]*255).round().clamp(0,255),
        (b[i]*255).round().clamp(0,255),
        255);
      i++;
    }
  }
  final blurred = img.gaussianBlur(img.Image.from(orig), radius: radius);
  i = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = orig.getPixel(x, y);
      final bl = blurred.getPixel(x, y);
      r[i] = (o.r/255.0 + amount*(o.r/255.0 - bl.r/255.0)).clamp(0.0,1.0);
      g[i] = (o.g/255.0 + amount*(o.g/255.0 - bl.g/255.0)).clamp(0.0,1.0);
      b[i] = (o.b/255.0 + amount*(o.b/255.0 - bl.b/255.0)).clamp(0.0,1.0);
      i++;
    }
  }
}

double _percentile(List<double> values, double pct) {
  if (values.isEmpty) return 0;
  final sorted = List<double>.from(values)..sort();
  final idx = ((pct / 100.0) * (sorted.length - 1)).clamp(0, sorted.length - 1);
  final lo = idx.floor(); final hi = idx.ceil();
  if (lo == hi) return sorted[lo];
  return sorted[lo] * (1 - (idx - lo)) + sorted[hi] * (idx - lo);
}
