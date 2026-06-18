import 'package:flutter/material.dart';

import '../../logic/light_table_color.dart';

/// Floating Kelvin / grid / lock controls for Light Table mode.
class LightTableControlBar extends StatelessWidget {
  final double kelvin;
  final bool gridVisible;
  final ValueChanged<double> onKelvinChanged;
  final VoidCallback onToggleGrid;
  final VoidCallback onLockScreen;

  const LightTableControlBar({
    super.key,
    required this.kelvin,
    required this.gridVisible,
    required this.onKelvinChanged,
    required this.onToggleGrid,
    required this.onLockScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: LightTableTokens.zinc900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${kelvin.round()} K',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Text(
                '5000 K',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '7000 K',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: Colors.white.withValues(alpha: 0.85),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.08),
            ),
            child: Slider(
              value: kelvin,
              min: LightTableTokens.kelvinMin,
              max: LightTableTokens.kelvinMax,
              onChanged: onKelvinChanged,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _ControlChip(
                label: gridVisible ? 'Grid: On' : 'Grid: Off',
                icon: Icons.grid_on_rounded,
                selected: gridVisible,
                onTap: onToggleGrid,
              ),
              const SizedBox(width: 10),
              _ControlChip(
                label: 'Lock Screen',
                icon: Icons.lock_outline_rounded,
                selected: false,
                onTap: onLockScreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ControlChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
