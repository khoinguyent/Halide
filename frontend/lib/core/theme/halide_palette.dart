import 'package:flutter/material.dart';

enum HalideThemeId {
  deepHarbor,
  mistyForest,
  oceanRoot,
  blueBell,
  cherryBlossom,
  morningFrost,
  carbonNight,
  harvestTable,
  spaceIndigo,
}

@immutable
class HalidePalette {
  const HalidePalette({
    required this.id,
    required this.displayName,
    required this.darkest,
    required this.accent,
    required this.mid,
    required this.light,
    required this.muted,
  });

  final HalideThemeId id;
  final String displayName;
  final Color darkest;
  final Color accent;
  final Color mid;
  final Color light;
  final Color muted;

  List<Color> get swatch => [darkest, accent, mid, light, muted];
}

abstract final class HalidePalettes {
  static const deepHarbor = HalidePalette(
    id: HalideThemeId.deepHarbor,
    displayName: 'Deep Harbor',
    darkest: Color(0xFF203959),
    accent: Color(0xFF416772),
    mid: Color(0xFF96ADA5),
    light: Color(0xFFABB7B3),
    muted: Color(0xFF839492),
  );

  static const mistyForest = HalidePalette(
    id: HalideThemeId.mistyForest,
    displayName: 'Misty Forest',
    darkest: Color(0xFF122F0B),
    accent: Color(0xFF275F3E),
    mid: Color(0xFF44785B),
    light: Color(0xFF6F9D87),
    muted: Color(0xFFB5CABA),
  );

  static const oceanRoot = HalidePalette(
    id: HalideThemeId.oceanRoot,
    displayName: 'Ocean Root',
    darkest: Color(0xFF937F71),
    accent: Color(0xFF7DC0B5),
    mid: Color(0xFFEEECE6),
    light: Color(0xFFE0CFBD),
    muted: Color(0xFFB6846A),
  );

  static const blueBell = HalidePalette(
    id: HalideThemeId.blueBell,
    displayName: 'Blue Bell',
    darkest: Color(0xFF4893C6),
    accent: Color(0xFF64A4CE),
    mid: Color(0xFF8DBEDC),
    light: Color(0xFFB7D7EA),
    muted: Color(0xFFE2EFF6),
  );

  static const cherryBlossom = HalidePalette(
    id: HalideThemeId.cherryBlossom,
    displayName: 'Cherry Blossom',
    darkest: Color(0xFFFB6F92),
    accent: Color(0xFFFF8FAB),
    mid: Color(0xFFFFB3C6),
    light: Color(0xFFFFC2D1),
    muted: Color(0xFFFFE5EC),
  );

  static const morningFrost = HalidePalette(
    id: HalideThemeId.morningFrost,
    displayName: 'Morning Frost',
    darkest: Color(0xFFADB5BD),
    accent: Color(0xFFCED4DA),
    mid: Color(0xFFDEE2E6),
    light: Color(0xFFE9ECEF),
    muted: Color(0xFFF8F9FA),
  );

  static const carbonNight = HalidePalette(
    id: HalideThemeId.carbonNight,
    displayName: 'Carbon Night',
    darkest: Color(0xFF212529),
    accent: Color(0xFF343A40),
    mid: Color(0xFF495057),
    light: Color(0xFF6C757D),
    muted: Color(0xFFADB5BD),
  );

  static const harvestTable = HalidePalette(
    id: HalideThemeId.harvestTable,
    displayName: 'Harvest Table',
    darkest: Color(0xFF540B0E),
    accent: Color(0xFF335C67),
    mid: Color(0xFF99A88C),
    light: Color(0xFFE09F3E),
    muted: Color(0xFFFFF3B0),
  );

  static const spaceIndigo = HalidePalette(
    id: HalideThemeId.spaceIndigo,
    displayName: 'Space Indigo',
    darkest: Color(0xFF22223B),
    accent: Color(0xFF4A4E69),
    mid: Color(0xFF9A8C98),
    light: Color(0xFFC9ADA7),
    muted: Color(0xFFF2E9E4),
  );

  static const all = [
    deepHarbor,
    mistyForest,
    oceanRoot,
    blueBell,
    cherryBlossom,
    morningFrost,
    carbonNight,
    harvestTable,
    spaceIndigo,
  ];

  static HalidePalette byId(HalideThemeId id) => switch (id) {
        HalideThemeId.deepHarbor => deepHarbor,
        HalideThemeId.mistyForest => mistyForest,
        HalideThemeId.oceanRoot => oceanRoot,
        HalideThemeId.blueBell => blueBell,
        HalideThemeId.cherryBlossom => cherryBlossom,
        HalideThemeId.morningFrost => morningFrost,
        HalideThemeId.carbonNight => carbonNight,
        HalideThemeId.harvestTable => harvestTable,
        HalideThemeId.spaceIndigo => spaceIndigo,
      };
}
