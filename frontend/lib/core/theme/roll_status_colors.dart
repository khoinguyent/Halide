import 'package:flutter/material.dart';
import '../../models/roll_status.dart';
import 'halide_colors.dart';

/// Workflow status colors derived from the active Halide palette.
abstract final class RollStatusColors {
  static Color forStatus(RollStatus status, HalideColors colors) {
    switch (status) {
      case RollStatus.shooting:
        return colors.accent;
      case RollStatus.lab:
        return colors.mid;
      case RollStatus.scanned:
        return colors.light;
      case RollStatus.syncing:
        return colors.accent;
      case RollStatus.archived:
        return colors.muted;
    }
  }
}
