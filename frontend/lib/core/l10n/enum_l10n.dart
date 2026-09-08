import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/gear_status.dart';
import 'package:frontend/models/roll_status.dart';
import 'package:frontend/core/theme/halide_palette.dart';

extension RollStatusL10n on RollStatus {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        RollStatus.shooting => l10n.rollStatusShooting,
        RollStatus.lab => l10n.rollStatusLab,
        RollStatus.syncing => l10n.rollStatusSyncing,
        RollStatus.scanned => l10n.rollStatusScanned,
        RollStatus.archived => l10n.rollStatusArchived,
      };
}

extension GearStatusL10n on GearStatus {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        GearStatus.active => l10n.gearStatusActive,
        GearStatus.repair => l10n.gearStatusRepair,
        GearStatus.sold => l10n.gearStatusSold,
        GearStatus.archived => l10n.gearStatusArchived,
      };
}

extension HalideThemeIdL10n on HalideThemeId {
  String localizedName(AppLocalizations l10n) => switch (this) {
        HalideThemeId.deepHarbor => l10n.themeDeepHarbor,
        HalideThemeId.mistyForest => l10n.themeMistyForest,
        HalideThemeId.oceanRoot => l10n.themeOceanRoot,
        HalideThemeId.blueBell => l10n.themeBlueBell,
        HalideThemeId.cherryBlossom => l10n.themeCherryBlossom,
        HalideThemeId.morningFrost => l10n.themeMorningFrost,
        HalideThemeId.carbonNight => l10n.themeCarbonNight,
        HalideThemeId.harvestTable => l10n.themeHarvestTable,
        HalideThemeId.spaceIndigo => l10n.themeSpaceIndigo,
      };
}

/// Uppercase label helper matching Halide UI style.
String halideCaps(String text) => text.toUpperCase();
