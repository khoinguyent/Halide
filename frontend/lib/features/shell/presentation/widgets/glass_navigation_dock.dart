import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frontend/config/app_config.dart';
import 'package:frontend/core/theme/halide_colors.dart';
import 'package:frontend/features/light_table/logic/light_table_color.dart';
import 'package:frontend/models/user_profile.dart';

class GlassNavigationDock extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;
  final VoidCallback onLightTableTap;
  final UserPlan plan;

  const GlassNavigationDock({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onLightTableTap,
    required this.plan,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HalideColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: colors.glassFill(0.12),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: colors.glassBorder(0.35),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(context, colors, Icons.camera_roll_outlined, 0),
                _buildNavItem(context, colors, Icons.photo_camera_outlined, 1),
                const SizedBox(width: 48),
                _buildNavItem(context, colors, Icons.exposure_outlined, 2, showLock: !plan.isPro),
                if (AppConfig.enableLightTable)
                  _buildActionItem(context, colors, LightTableTokens.navIcon, onLightTableTap)
                else
                  _buildNavItem(context, colors, Icons.person_outline, 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    HalideColors colors,
    IconData icon,
    int index, {
    bool showLock = false,
  }) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTabSelected(index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            icon,
            color: isSelected ? colors.textPrimary : colors.iconMuted(),
            size: 28,
          ),
          if (showLock)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colors.sage,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock,
                  size: 10,
                  color: colors.navy,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    HalideColors colors,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: 'Light Table',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(
              icon,
              color: colors.iconMuted(),
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
