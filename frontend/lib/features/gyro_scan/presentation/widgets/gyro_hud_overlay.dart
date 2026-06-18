import 'package:flutter/material.dart';

import '../../logic/gyro_scan_constants.dart';

enum GyroFeedback { locked, guiding, ready }

/// Target ring + smoothly gliding gyro dot drawn over the camera preview.
class GyroHudOverlay extends StatelessWidget {
  final GyroFeedback feedback;
  final Offset dotOffset;
  final bool snapToCenter;

  const GyroHudOverlay({
    super.key,
    required this.feedback,
    required this.dotOffset,
    required this.snapToCenter,
  });

  Color get _dotColor {
    switch (feedback) {
      case GyroFeedback.locked:
        return Colors.grey;
      case GyroFeedback.guiding:
        return Colors.orange;
      case GyroFeedback.ready:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
          final target = snapToCenter ? center : center + dotOffset;

          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _TargetRingPainter(
                  center: center,
                  feedback: feedback,
                ),
              ),
              AnimatedPositioned(
                duration: snapToCenter
                    ? const Duration(milliseconds: 120)
                    : const Duration(milliseconds: 80),
                curve: snapToCenter ? Curves.easeOutBack : Curves.easeOutCubic,
                left: target.dx - 10,
                top: target.dy - 10,
                child: _GyroDot(color: _dotColor, glowing: feedback == GyroFeedback.ready),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GyroDot extends StatelessWidget {
  final Color color;
  final bool glowing;

  const _GyroDot({required this.color, required this.glowing});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (glowing)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.55),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetRingPainter extends CustomPainter {
  final Offset center;
  final GyroFeedback feedback;

  _TargetRingPainter({required this.center, required this.feedback});

  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, gyroTargetRingRadius, ringPaint);

    final innerRing = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, gyroTargetRingRadius * 0.72, innerRing);

    if (feedback == GyroFeedback.ready) {
      final readyRing = Paint()
        ..color = Colors.green.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, gyroTargetRingRadius, readyRing);
    }
  }

  @override
  bool shouldRepaint(covariant _TargetRingPainter oldDelegate) =>
      oldDelegate.feedback != feedback || oldDelegate.center != center;
}
