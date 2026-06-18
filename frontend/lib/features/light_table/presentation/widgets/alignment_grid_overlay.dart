import 'package:flutter/material.dart';

import '../../logic/light_table_color.dart';

/// Ultra-fine alignment grid for positioning film strips on the backlight.
class AlignmentGridOverlay extends StatelessWidget {
  const AlignmentGridOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: const _AlignmentGridPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AlignmentGridPainter extends CustomPainter {
  const _AlignmentGridPainter();

  static const _gridColor = LightTableTokens.zinc300;
  /// Slightly stronger than spec minimum so lines remain visible on white backlight.
  static const _gridOpacity = 0.28;
  static const _lineWidth = 0.5;
  static const _cellSize = 32.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()
      ..color = _gridColor.withValues(alpha: _gridOpacity)
      ..strokeWidth = _lineWidth
      ..style = PaintingStyle.stroke;

    for (var x = 0.0; x <= size.width; x += _cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += _cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
