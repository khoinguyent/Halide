import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Stamp size as a fraction of min(display width, height).
/// Min = previous default (keeps QR center logo scannable); max stays within EC-H safe range.
const double kPrintStampMinSize = 0.28;
const double kPrintStampDefaultSize = 0.28;
const double kPrintStampMaxSize = 0.40;

/// Square stamp crop in **source image** normalized coordinates.
/// [size] is the side length relative to `min(imageWidth, imageHeight)`.
class PrintQrStampCrop {
  const PrintQrStampCrop({
    required this.centerX,
    required this.centerY,
    required this.size,
  });

  final double centerX;
  final double centerY;
  final double size;

  Map<String, dynamic> toApi() => {
        'center_x': centerX.clamp(0.0, 1.0),
        'center_y': centerY.clamp(0.0, 1.0),
        // Backend maps this into QR logo size; keep within scannable band.
        'size': size.clamp(kPrintStampMinSize, kPrintStampMaxSize),
      };
}

/// Maps a stamp placed on a BoxFit.cover display into source-image space.
PrintQrStampCrop mapStampToSource({
  required Size displaySize,
  required double imageAspect,
  required double stampCx,
  required double stampCy,
  required double stampSize,
}) {
  final displayAspect = displaySize.width / displaySize.height;
  late final double visLeft;
  late final double visTop;
  late final double visW;
  late final double visH;
  if (imageAspect > displayAspect) {
    visH = 1.0;
    visW = displayAspect / imageAspect;
    visLeft = (1.0 - visW) / 2.0;
    visTop = 0.0;
  } else {
    visW = 1.0;
    visH = imageAspect / displayAspect;
    visLeft = 0.0;
    visTop = (1.0 - visH) / 2.0;
  }

  final stampSidePx = stampSize * math.min(displaySize.width, displaySize.height);
  final stampWFracOfVisible = stampSidePx / displaySize.width;
  final sideAsFracOfImageWidth = stampWFracOfVisible * visW;
  // size relative to min(imageW, imageH)
  final size = imageAspect <= 1.0
      ? sideAsFracOfImageWidth
      : sideAsFracOfImageWidth / imageAspect;

  return PrintQrStampCrop(
    centerX: (visLeft + stampCx * visW).clamp(0.0, 1.0),
    centerY: (visTop + stampCy * visH).clamp(0.0, 1.0),
    size: size.clamp(kPrintStampMinSize, kPrintStampMaxSize),
  );
}

/// Postage-stamp perforation path (matches backend QR badge silhouette).
Path postageStampPath(Size size, {int teeth = 14, double depth = 3.5}) {
  final path = Path();
  final stepX = size.width / teeth;
  final stepY = size.height / teeth;

  path.moveTo(0, depth);
  for (var i = 0; i < teeth; i++) {
    final x = i * stepX;
    path.lineTo(x + stepX * 0.35, 0);
    path.lineTo(x + stepX * 0.65, depth);
    path.lineTo(x + stepX, depth);
  }
  for (var i = 0; i < teeth; i++) {
    final y = i * stepY;
    path.lineTo(size.width - depth, y + stepY * 0.35);
    path.lineTo(size.width, y + stepY * 0.65);
    path.lineTo(size.width - depth, y + stepY);
  }
  for (var i = teeth; i > 0; i--) {
    final x = i * stepX;
    path.lineTo(x - stepX * 0.35, size.height);
    path.lineTo(x - stepX * 0.65, size.height - depth);
    path.lineTo(x - stepX, size.height - depth);
  }
  for (var i = teeth; i > 0; i--) {
    final y = i * stepY;
    path.lineTo(depth, y - stepY * 0.35);
    path.lineTo(0, y - stepY * 0.65);
    path.lineTo(depth, y - stepY);
  }
  path.close();
  return path;
}

/// Decorative perforated stamp frame over the photo.
class PrintStampFrame extends StatelessWidget {
  const PrintStampFrame({
    super.key,
    required this.size,
    required this.locked,
    this.child,
  });

  final double size;
  final bool locked;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final border = locked ? const Color(0xFFE8C547) : Colors.white;
    final depth = (size * 0.028).clamp(2.5, 5.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StampPerforationPainter(
          color: border.withValues(alpha: locked ? 0.95 : 0.85),
          locked: locked,
          depth: depth,
        ),
        child: ClipPath(
          clipper: _StampClipper(depth: depth),
          child: Padding(
            padding: EdgeInsets.all(depth + 2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: border.withValues(alpha: 0.9), width: 1.5),
                color: Colors.black.withValues(alpha: locked ? 0.0 : 0.08),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _StampClipper extends CustomClipper<Path> {
  _StampClipper({required this.depth});
  final double depth;

  @override
  Path getClip(Size size) => postageStampPath(size, depth: depth);

  @override
  bool shouldReclip(covariant _StampClipper oldClipper) => oldClipper.depth != depth;
}

class _StampPerforationPainter extends CustomPainter {
  _StampPerforationPainter({
    required this.color,
    required this.locked,
    required this.depth,
  });

  final Color color;
  final bool locked;
  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = postageStampPath(size, depth: depth);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path, paint);

    if (locked) {
      final fill = Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _StampPerforationPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.locked != locked ||
      oldDelegate.depth != depth;
}
