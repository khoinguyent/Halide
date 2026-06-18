import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive metering pin — 28px diameter, orange hair-cross, draggable.
class MeteringPinWidget extends StatelessWidget {
  static const double pinDiameter = 28.0;
  static const Color accentColor = Color(0xFFF97316);

  final double ev;
  final bool isDragging;
  final VoidCallback? onDoubleTap;

  const MeteringPinWidget({
    super.key,
    required this.ev,
    this.isDragging = false,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // EV readout label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'EV ${ev.toStringAsFixed(1)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onDoubleTap: () {
            HapticFeedback.mediumImpact();
            onDoubleTap?.call();
          },
          child: Container(
            width: pinDiameter,
            height: pinDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor,
                width: isDragging ? 2.5 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.35),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CustomPaint(
              painter: _HairCrossPainter(),
            ),
          ),
        ),
      ],
    );
  }
}

class _HairCrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MeteringPinWidget.accentColor
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    const arm = 6.0;

    canvas.drawLine(Offset(cx - arm, cy), Offset(cx + arm, cy), paint);
    canvas.drawLine(Offset(cx, cy - arm), Offset(cx, cy + arm), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
