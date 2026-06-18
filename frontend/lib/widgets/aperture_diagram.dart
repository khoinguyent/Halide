import 'dart:math';

import 'package:flutter/material.dart';

/// Iris-style aperture diagram (same visual as roll shot-log EXIF capture).
class AperturePainter extends CustomPainter {
  final double aperture;
  final double maxAperture;
  final double minAperture;

  AperturePainter({
    required this.aperture,
    required this.maxAperture,
    required this.minAperture,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final t = (log(aperture) - log(minAperture)) / (log(maxAperture) - log(minAperture));
    final openFactor = 0.15 + (0.8 * t);
    final holeRadius = radius * openFactor;

    final bladePaint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF0A0A0A));
    canvas.drawCircle(center, radius, borderPaint);

    const int numBlades = 6;
    final double angleStep = (2 * pi) / numBlades;

    for (int i = 0; i < numBlades; i++) {
      final double angle = i * angleStep;

      final path = Path();

      final p1 = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );

      final p2 = Offset(
        center.dx + radius * cos(angle + angleStep * 1.5),
        center.dy + radius * sin(angle + angleStep * 1.5),
      );

      final pTangent = Offset(
        center.dx + holeRadius * cos(angle + angleStep * 0.5),
        center.dy + holeRadius * sin(angle + angleStep * 0.5),
      );

      final double tangentAngle = angle + angleStep * 0.5 + pi / 2;
      final double lineLength = radius * 2;

      final pEdgeStart = Offset(
        pTangent.dx + lineLength * cos(tangentAngle),
        pTangent.dy + lineLength * sin(tangentAngle),
      );
      final pEdgeEnd = Offset(
        pTangent.dx - lineLength * cos(tangentAngle),
        pTangent.dy - lineLength * sin(tangentAngle),
      );

      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(pEdgeStart.dx, pEdgeStart.dy);
      path.lineTo(pEdgeEnd.dx, pEdgeEnd.dy);
      path.close();

      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
      canvas.drawPath(path, bladePaint);
      canvas.drawPath(path, borderPaint);
      canvas.restore();
    }

    final holePath = Path();
    for (int i = 0; i <= numBlades; i++) {
      final double angle = i * angleStep + angleStep * 0.5;
      final double rVertex = holeRadius / cos(pi / numBlades);
      final p = Offset(
        center.dx + rVertex * cos(angle),
        center.dy + rVertex * sin(angle),
      );
      if (i == 0) {
        holePath.moveTo(p.dx, p.dy);
      } else {
        holePath.lineTo(p.dx, p.dy);
      }
    }

    canvas.drawPath(holePath, Paint()..blendMode = BlendMode.clear);

    canvas.drawPath(
      holePath,
      Paint()
        ..color = Colors.orange.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant AperturePainter oldDelegate) =>
      oldDelegate.aperture != aperture ||
      oldDelegate.maxAperture != maxAperture ||
      oldDelegate.minAperture != minAperture;
}

String formatApertureFStop(double aperture) {
  if (aperture == aperture.roundToDouble()) {
    return aperture.toStringAsFixed(0);
  }
  return aperture.toStringAsFixed(1);
}

int nearestApertureIndex(List<double> stops, double value) {
  if (stops.isEmpty) return 0;
  var best = 0;
  var bestDiff = (stops[0] - value).abs();
  for (var i = 1; i < stops.length; i++) {
    final d = (stops[i] - value).abs();
    if (d < bestDiff) {
      bestDiff = d;
      best = i;
    }
  }
  return best;
}

SliderThemeData halideApertureSliderTheme(BuildContext context) {
  return SliderTheme.of(context).copyWith(
    activeTrackColor: Colors.orange.withOpacity(0.8),
    inactiveTrackColor: Colors.white10,
    trackHeight: 2.0,
    thumbColor: Colors.white,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
    overlayColor: Colors.orange.withOpacity(0.2),
    tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1),
    activeTickMarkColor: Colors.orange,
    inactiveTickMarkColor: Colors.white24,
  );
}
