import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'guidance_tokens.dart';

/// Single-step coach mark: zinc scrim, orange ring, dark modal copy.
///
/// Do not set [TargetFocus.color] (it tints the full-screen dim).
TutorialCoachMark buildSingleStepArchiveGuidance({
  required GlobalKey targetKey,
  required String identify,
  required String body,
  required VoidCallback onCompleted,
  ContentAlign contentAlign = ContentAlign.bottom,
  EdgeInsets contentPadding = const EdgeInsets.fromLTRB(20, 0, 20, 28),
  double radius = 16,
  double paddingFocus = 8,
  Future<void> Function(TargetFocus)? beforeFocus,
}) {
  return TutorialCoachMark(
    beforeFocus: beforeFocus,
    targets: [
      TargetFocus(
        identify: identify,
        keyTarget: targetKey,
        shape: ShapeLightFocus.RRect,
        radius: radius,
        paddingFocus: paddingFocus,
        borderSide: const BorderSide(color: GuidanceTokens.orange500, width: 2),
        enableOverlayTab: true,
        enableTargetTab: false,
        contents: [
          TargetContent(
            align: contentAlign,
            padding: contentPadding,
            builder: (ctx, controller) {
              return _GuidanceCoachCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      body,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: GuidanceTokens.orange500,
                          foregroundColor: GuidanceTokens.zinc950,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: () {
                          controller.next();
                        },
                        child: const Text(
                          'GOT IT',
                          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ],
    colorShadow: GuidanceTokens.zinc950,
    opacityShadow: 0.92,
    pulseEnable: true,
    pulseAnimationDuration: const Duration(milliseconds: 800),
    paddingFocus: 10,
    hideSkip: true,
    focusAnimationDuration: const Duration(milliseconds: 500),
    unFocusAnimationDuration: const Duration(milliseconds: 350),
    onFinish: onCompleted,
  );
}

class _GuidanceCoachCard extends StatelessWidget {
  const _GuidanceCoachCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GuidanceTokens.zinc950,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GuidanceTokens.orange500.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 20,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
