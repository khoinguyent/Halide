import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/light_table_color.dart';

/// Bottom-center unlock control shown while the touch-shield is active.
///
/// Updated UX: **tap to unlock** (no press-and-hold).
class TouchShieldOverlay extends StatefulWidget {
  final VoidCallback onUnlocked;

  const TouchShieldOverlay({
    super.key,
    required this.onUnlocked,
  });

  @override
  State<TouchShieldOverlay> createState() => _TouchShieldOverlayState();
}

class _TouchShieldOverlayState extends State<TouchShieldOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      lowerBound: 0.45,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _unlock() {
    HapticFeedback.mediumImpact();
    widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulseOpacity = _pulseController.value;
        return SizedBox(
          width: 88,
          height: 88,
          child: Center(
            child: Material(
              color: LightTableTokens.zinc900.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _unlock,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    color: Colors.white.withValues(alpha: pulseOpacity * 0.7),
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
