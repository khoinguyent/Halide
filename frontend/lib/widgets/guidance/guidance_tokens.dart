import 'package:flutter/material.dart';
import '../../core/theme/halide_colors.dart';

/// Brand palette for guidance surfaces (aliases [HalideColors]).
abstract final class GuidanceTokens {
  static Color zinc950(BuildContext context) =>
      HalideColors.of(context).background;

  static Color orange500(BuildContext context) =>
      HalideColors.of(context).accent;
}
