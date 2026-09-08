import 'package:flutter/material.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../../../../core/theme/halide_colors.dart';

class StorageTierSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  final bool isFree;

  const StorageTierSelector({
    Key? key,
    this.selectedIndex = 0,
    this.onSelected,
    this.isFree = false,
  }) : super(key: key);

  List<TierData> _tiers(AppLocalizations l10n) => [
        TierData(
          label: l10n.storageLocal,
          badge: l10n.free,
          icon: Icons.smartphone_outlined,
        ),
        TierData(
          label: l10n.storagePersonalCloud,
          badge: l10n.tierBadgeByo,
          icon: Icons.cloud_outlined,
        ),
        TierData(
          label: l10n.storageSystemCloud,
          badge: l10n.planPro,
          icon: Icons.auto_awesome,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tiers = _tiers(l10n);
    final onSelected = this.onSelected;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: List.generate(tiers.length, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == tiers.length - 1 ? 0 : 8),
                child: _TierSegment(
                  data: tiers[index],
                  isSelected: selectedIndex == index,
                  isLocked: isFree && index > 1,
                  onTap: onSelected == null ? null : () => onSelected(index),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class TierData {
  final String label;
  final String badge;
  final IconData icon;

  const TierData({
    required this.label,
    required this.badge,
    required this.icon,
  });
}

class _TierSegment extends StatelessWidget {
  final TierData data;
  final bool isSelected;
  final VoidCallback? onTap;

  final bool isLocked;

  const _TierSegment({
    Key? key,
    required this.data,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final accent = HalideColors.of(context).accent;
    final inactiveOpacity = 0.45;
    final badgeIsPro = data.badge.toUpperCase() == context.l10n.planPro;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isSelected ? 0.05 : 0.00),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? accent : Colors.white.withOpacity(0.10),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.22),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 0),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isLocked ? Icons.lock_outline_rounded : data.icon,
                size: 26,
                color: isSelected ? Colors.white : Colors.white.withOpacity(isLocked ? 0.25 : inactiveOpacity),
              ),
              const SizedBox(height: 8),
              Text(
                data.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(inactiveOpacity),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeIsPro
                      ? accent.withOpacity(isSelected ? 0.95 : 0.70)
                      : Colors.white.withOpacity(isSelected ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  data.badge.toUpperCase(),
                  style: TextStyle(
                    color: badgeIsPro
                        ? Colors.black.withOpacity(0.9)
                        : Colors.white.withOpacity(isSelected ? 0.78 : 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
