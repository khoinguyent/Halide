import 'package:flutter/material.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import '../core/theme/halide_colors.dart';

class FolderTabs extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;
  final int photoCount;
  final int shotCount;

  const FolderTabs({
    Key? key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.photoCount,
    required this.shotCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HalideColors.of(context).glassFill(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabItem(
              label: l10n.photos,
              count: photoCount,
              isSelected: selectedIndex == 0,
              onTap: () => onTabSelected(0),
            ),
          ),
          Expanded(
            child: _TabItem(
              label: l10n.shotLog,
              count: shotCount,
              isSelected: selectedIndex == 1,
              onTap: () => onTabSelected(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? HalideColors.of(context).slateTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: HalideColors.of(context).slateTeal.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: isSelected ? HalideColors.of(context).ash : HalideColors.of(context).textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? HalideColors.of(context).navy.withValues(alpha: 0.15)
                    : HalideColors.of(context).glassFill(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? HalideColors.of(context).navy : HalideColors.of(context).steel,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
