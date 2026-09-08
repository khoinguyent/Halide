import 'package:flutter/material.dart';

import '../../logic/film_format.dart';
import '../../logic/gyro_scan_constants.dart';

enum GyroFeedback { locked, guiding, ready }

/// Readiness of the camera's autofocus system.
enum FocusState {
  /// Gyro not yet within AeAf-lock threshold — camera in continuous AF.
  idle,

  /// Gyro leveled; camera was asked to focus but settle delay not elapsed.
  focusing,

  /// Focus lock acquired — safe to capture.
  settled,
}

// ─────────────────────────────────────────────────────────────────────────────
// FilmFrameOverlay
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen overlay that draws:
///   1. A dark vignette everywhere except the format frame box.
///   2. Corner markers styled to the selected [FilmFormat].
///   3. A pulsing border that reflects focus state.
///   4. A gyro-level dot constrained to the frame box interior.
///   5. A small format label badge above the frame box.
class FilmFrameOverlay extends StatefulWidget {
  final FilmFormat format;
  final GyroFeedback feedback;
  final Offset dotOffset;
  final bool snapToCenter;
  final FocusState focusState;

  const FilmFrameOverlay({
    super.key,
    required this.format,
    required this.feedback,
    required this.dotOffset,
    required this.snapToCenter,
    required this.focusState,
  });

  @override
  State<FilmFrameOverlay> createState() => _FilmFrameOverlayState();
}

class _FilmFrameOverlayState extends State<FilmFrameOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color get _accent => switch (widget.focusState) {
        FocusState.settled  => Colors.green,
        FocusState.focusing => Colors.orange,
        FocusState.idle     => widget.feedback == GyroFeedback.guiding
            ? Colors.orange
            : Colors.white54,
      };

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(builder: (ctx, constraints) {
        final screen = Size(constraints.maxWidth, constraints.maxHeight);
        final box = widget.format.frameBox(screen);
        final accent = _accent;

        // Dot position is clamped to the interior of the frame box.
        final Offset dotPos;
        if (widget.snapToCenter) {
          dotPos = box.center;
        } else {
          dotPos = Offset(
            (box.center.dx + widget.dotOffset.dx)
                .clamp(box.left + 10, box.right - 10),
            (box.center.dy + widget.dotOffset.dy)
                .clamp(box.top + 10, box.bottom - 10),
          );
        }

        return AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _FilmFramePainter(
                    format: widget.format,
                    frameRect: box,
                    focusState: widget.focusState,
                    feedback: widget.feedback,
                    accent: accent,
                    pulseAlpha: _pulseAnim.value,
                  ),
                ),
                // Gyro dot — animated smoothly inside the frame box.
                AnimatedPositioned(
                  duration: widget.snapToCenter
                      ? const Duration(milliseconds: 120)
                      : const Duration(milliseconds: 80),
                  curve: widget.snapToCenter
                      ? Curves.easeOutBack
                      : Curves.easeOutCubic,
                  left: dotPos.dx - 10,
                  top: dotPos.dy - 10,
                  child: _GyroDot(
                    color: accent,
                    glowing: widget.focusState == FocusState.settled,
                  ),
                ),
              ],
            );
          },
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FilmFramePainter
// ─────────────────────────────────────────────────────────────────────────────

class _FilmFramePainter extends CustomPainter {
  final FilmFormat format;
  final Rect frameRect;
  final FocusState focusState;
  final GyroFeedback feedback;
  final Color accent;
  final double pulseAlpha;

  const _FilmFramePainter({
    required this.format,
    required this.frameRect,
    required this.focusState,
    required this.feedback,
    required this.accent,
    required this.pulseAlpha,
  });

  static const _vignette = Color(0xBB000000);

  @override
  void paint(Canvas canvas, Size size) {
    final cornerR = format.isMediumFormat ? 2.5 : 1.5;

    // ── 1. Vignette with transparent punch-through ────────────────────────────
    final vigPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(frameRect, Radius.circular(cornerR)));
    vigPath.fillType = PathFillType.evenOdd;
    canvas.drawPath(vigPath, Paint()..color = _vignette);

    // ── 2. Format-specific frame markers ────────────────────────────────────
    if (format.isMediumFormat) {
      _draw120Border(canvas, cornerR);
    } else {
      _draw35Corners(canvas);
    }

    // ── 3. Focus-state animated border ───────────────────────────────────────
    switch (focusState) {
      case FocusState.focusing:
        canvas.drawRRect(
          RRect.fromRectAndRadius(frameRect, Radius.circular(cornerR)),
          Paint()
            ..color = Colors.orange.withValues(alpha: pulseAlpha * 0.80)
            ..style = PaintingStyle.stroke
            ..strokeWidth = format.isMediumFormat ? 3.5 : 2.5,
        );
      case FocusState.settled:
        canvas.drawRRect(
          RRect.fromRectAndRadius(frameRect, Radius.circular(cornerR)),
          Paint()
            ..color = Colors.green.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = format.isMediumFormat ? 3.0 : 2.0,
        );
      case FocusState.idle:
        break;
    }

    // ── 4. Format label ──────────────────────────────────────────────────────
    _drawLabel(canvas);
  }

  // 35 mm — classic camera-viewfinder corner brackets.
  void _draw35Corners(Canvas canvas) {
    final len = frameRect.shortestSide * 0.10;
    final p = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.square;

    // Faint full-rectangle ghost.
    canvas.drawRect(
      frameRect,
      Paint()
        ..color = accent.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );

    final r = frameRect;
    // TL
    canvas.drawLine(r.topLeft, r.topLeft + Offset(len, 0), p);
    canvas.drawLine(r.topLeft, r.topLeft + Offset(0, len), p);
    // TR
    canvas.drawLine(r.topRight, r.topRight + Offset(-len, 0), p);
    canvas.drawLine(r.topRight, r.topRight + Offset(0, len), p);
    // BL
    canvas.drawLine(r.bottomLeft, r.bottomLeft + Offset(len, 0), p);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + Offset(0, -len), p);
    // BR
    canvas.drawLine(r.bottomRight, r.bottomRight + Offset(-len, 0), p);
    canvas.drawLine(r.bottomRight, r.bottomRight + Offset(0, -len), p);
  }

  // 120 medium format — full border with heavier corner accents.
  void _draw120Border(Canvas canvas, double cornerR) {
    // Thin perimeter.
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, Radius.circular(cornerR)),
      Paint()
        ..color = accent.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Bold corner ticks.
    final len = frameRect.shortestSide * 0.085;
    final thick = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.butt;

    final r = frameRect;
    canvas.drawLine(r.topLeft, r.topLeft + Offset(len, 0), thick);
    canvas.drawLine(r.topLeft, r.topLeft + Offset(0, len), thick);
    canvas.drawLine(r.topRight, r.topRight + Offset(-len, 0), thick);
    canvas.drawLine(r.topRight, r.topRight + Offset(0, len), thick);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + Offset(len, 0), thick);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + Offset(0, -len), thick);
    canvas.drawLine(r.bottomRight, r.bottomRight + Offset(-len, 0), thick);
    canvas.drawLine(r.bottomRight, r.bottomRight + Offset(0, -len), thick);

    // 6×6 only: subtle centre crosshair to aid square framing.
    if (format == FilmFormat.mm120_66) {
      final cross = Paint()
        ..color = accent.withValues(alpha: 0.22)
        ..strokeWidth = 0.7;
      canvas.drawLine(
        Offset(r.center.dx, r.top + len),
        Offset(r.center.dx, r.bottom - len),
        cross,
      );
      canvas.drawLine(
        Offset(r.left + len, r.center.dy),
        Offset(r.right - len, r.center.dy),
        cross,
      );
    }
  }

  void _drawLabel(Canvas canvas) {
    final tp = TextPainter(
      text: TextSpan(
        text: format.shortName,
        style: const TextStyle(
          color: Color(0xCCFFFFFF),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(frameRect.left, frameRect.top - 18));
  }

  @override
  bool shouldRepaint(covariant _FilmFramePainter old) =>
      old.format != format ||
      old.frameRect != frameRect ||
      old.focusState != focusState ||
      old.accent != accent ||
      old.pulseAlpha != pulseAlpha;
}

// ─────────────────────────────────────────────────────────────────────────────
// GyroHudOverlay  (kept for reference; replaced by FilmFrameOverlay in HUD)
// ─────────────────────────────────────────────────────────────────────────────

/// Legacy circular target-ring overlay — superseded by [FilmFrameOverlay].
@Deprecated('Use FilmFrameOverlay instead')
class GyroHudOverlay extends StatefulWidget {
  final GyroFeedback feedback;
  final Offset dotOffset;
  final bool snapToCenter;
  final FocusState focusState;

  const GyroHudOverlay({
    super.key,
    required this.feedback,
    required this.dotOffset,
    required this.snapToCenter,
    required this.focusState,
  });

  @override
  State<GyroHudOverlay> createState() => _GyroHudOverlayState();
}

class _GyroHudOverlayState extends State<GyroHudOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.25, end: 0.9).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _dotColor => switch (widget.feedback) {
        GyroFeedback.locked  => Colors.grey,
        GyroFeedback.guiding => Colors.orange,
        GyroFeedback.ready   => Colors.green,
      };

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final center =
              Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
          final target =
              widget.snapToCenter ? center : center + widget.dotOffset;

          return AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _TargetRingPainter(
                      center: center,
                      feedback: widget.feedback,
                      focusState: widget.focusState,
                      pulseAlpha: _pulseAnim.value,
                    ),
                  ),
                  AnimatedPositioned(
                    duration: widget.snapToCenter
                        ? const Duration(milliseconds: 120)
                        : const Duration(milliseconds: 80),
                    curve: widget.snapToCenter
                        ? Curves.easeOutBack
                        : Curves.easeOutCubic,
                    left: target.dx - 10,
                    top: target.dy - 10,
                    child: _GyroDot(
                      color: _dotColor,
                      glowing: widget.feedback == GyroFeedback.ready,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared primitives
// ─────────────────────────────────────────────────────────────────────────────

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
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35), width: 1.5),
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
  final FocusState focusState;
  final double pulseAlpha;

  const _TargetRingPainter({
    required this.center,
    required this.feedback,
    required this.focusState,
    required this.pulseAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      center,
      gyroTargetRingRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      center,
      gyroTargetRingRadius * 0.72,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    switch (focusState) {
      case FocusState.idle:
        break;
      case FocusState.focusing:
        canvas.drawCircle(
          center,
          gyroTargetRingRadius + 5,
          Paint()
            ..color =
                const Color(0xFFFFA500).withValues(alpha: pulseAlpha * 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      case FocusState.settled:
        canvas.drawCircle(
          center,
          gyroTargetRingRadius,
          Paint()
            ..color = Colors.green.withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _TargetRingPainter old) =>
      old.feedback != feedback ||
      old.focusState != focusState ||
      old.pulseAlpha != pulseAlpha ||
      old.center != center;
}
