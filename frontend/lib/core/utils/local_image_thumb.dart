import 'package:flutter/material.dart';

/// Decode extent for a [logicalSide]×[logicalSide] widget (avoids full-res decode).
int localImageDecodeCacheExtent(BuildContext context, double logicalSide) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (logicalSide * dpr).round().clamp(64, 2048);
}

/// 3-column gear grids: horizontal padding 40, cross-axis spacing 8 (see gear gallery UI).
int gearGalleryGridThumbCacheExtent(BuildContext context, {int crossAxisCount = 3}) {
  const horizontalPadding = 40.0;
  const spacing = 8.0;
  final w = MediaQuery.sizeOf(context).width;
  final cell = (w - horizontalPadding - spacing * (crossAxisCount - 1)) / crossAxisCount;
  return localImageDecodeCacheExtent(context, cell);
}
