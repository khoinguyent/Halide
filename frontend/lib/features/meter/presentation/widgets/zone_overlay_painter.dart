import 'package:flutter/material.dart';

import '../../logic/advanced_spot_metering_engine.dart';
import 'zone_legend_help_sheet.dart';

/// CPU fallback zone grid (Skia / shader unavailable).
class ZoneOverlayPainter extends CustomPainter {
  final List<int> colorGrid;
  final int gridWidth;
  final int gridHeight;
  final double opacity;

  ZoneOverlayPainter({
    required this.colorGrid,
    required this.gridWidth,
    required this.gridHeight,
    this.opacity = 0.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (colorGrid.length != gridWidth * gridHeight) return;

    final cellW = size.width / gridWidth;
    final cellH = size.height / gridHeight;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var gy = 0; gy < gridHeight; gy++) {
      for (var gx = 0; gx < gridWidth; gx++) {
        final argb = colorGrid[gy * gridWidth + gx];
        paint.color = Color(argb).withValues(alpha: opacity);
        canvas.drawRect(
          Rect.fromLTWH(gx * cellW, gy * cellH, cellW + 0.5, cellH + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ZoneOverlayPainter oldDelegate) {
    return oldDelegate.colorGrid != colorGrid ||
        oldDelegate.opacity != opacity;
  }
}

/// Bottom legend HUD: 11-zone color strip with zone labels.
class ZoneLegendHud extends StatelessWidget {
  /// Compact padding when docked between the exposure panel and tab bar.
  final bool dockBelowExposurePanel;

  const ZoneLegendHud({
    super.key,
    this.dockBelowExposurePanel = false,
  });

  static const double preferredHeight = 36;
  static const double _helpButtonWidth = 32;

  static const _zoneCount = 11;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, dockBelowExposurePanel ? 4 : bottomPad + 8),
      child: SizedBox(
        height: dockBelowExposurePanel ? preferredHeight : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      children: [
                        for (var i = 0; i < _zoneCount; i++)
                          Expanded(
                            child: Container(
                              height: 10,
                              color: AdvancedSpotMeteringEngine.zoneColors[i],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Zone 0',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Zone V',
                        style: TextStyle(
                          color: const Color(0xFF00FF00).withValues(alpha: 0.9),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Zone X',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: _helpButtonWidth,
              height: _helpButtonWidth,
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => showZoneOverlayHelpSheet(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact inline legend (legacy).
class ZoneLegendBar extends StatelessWidget {
  const ZoneLegendBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < AdvancedSpotMeteringEngine.zoneColors.length; i++)
            Container(
              width: 14,
              height: 8,
              color: AdvancedSpotMeteringEngine.zoneColors[i],
            ),
        ],
      ),
    );
  }
}
