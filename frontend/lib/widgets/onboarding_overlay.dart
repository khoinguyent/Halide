import 'dart:ui';
import 'package:flutter/material.dart';

class OnboardingStep {
  final String title;
  final String description;
  final IconData icon;
  final Alignment spotlightAlign;
  final double spotlightRadius;

  const OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.spotlightAlign,
    this.spotlightRadius = 32,
  });
}

/// Full-screen overlay that walks a first-time user through the bottom nav bar
/// and FAB. Steps:
///   0  Rolls (Archive)
///   1  Quick Add (FAB) — "add new roll"
///   2  Gear Locker
///   3  Quick Add (FAB) — "add new gear"
///   4  Light Meter
///   5  Profile
class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingOverlay({Key? key, required this.onComplete}) : super(key: key);

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  // Nav bar icon positions mapped as Alignment(x, y).
  // Locker(0)≈-0.72  Rolls(1)≈-0.28  [FAB center 0.0]  Meter(2)≈0.28  Profile(3)≈0.72
  static const _steps = [
    OnboardingStep(
      title: 'The Archive',
      description:
          'All your film rolls live here — track every shot from loading to developing.',
      icon: Icons.filter_center_focus,
      spotlightAlign: Alignment(-0.28, 1.0),
    ),
    OnboardingStep(
      title: 'Quick Add',
      description:
          'Tap this button to start a new roll and begin shooting.',
      icon: Icons.add_a_photo,
      spotlightAlign: Alignment(0.0, 0.88),
      spotlightRadius: 44,
    ),
    OnboardingStep(
      title: 'Gear Locker',
      description:
          'Browse and manage all your cameras & lenses in one place.',
      icon: Icons.camera_roll_outlined,
      spotlightAlign: Alignment(-0.72, 1.0),
    ),
    OnboardingStep(
      title: 'Quick Add',
      description:
          'When you\'re in the Locker tab, this button adds new gear instead.',
      icon: Icons.add_a_photo,
      spotlightAlign: Alignment(0.0, 0.88),
      spotlightRadius: 44,
    ),
    OnboardingStep(
      title: 'Light Meter',
      description:
          'A built-in light meter to help you nail exposure every time.',
      icon: Icons.light_mode_outlined,
      spotlightAlign: Alignment(0.28, 1.0),
    ),
    OnboardingStep(
      title: 'Profile & Settings',
      description:
          'Your account and settings. Head to Settings to connect your Google account for cloud sync.',
      icon: Icons.person_outline,
      spotlightAlign: Alignment(0.72, 1.0),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < _steps.length - 1) {
      _controller.reverse().then((_) {
        if (!mounted) return;
        setState(() => _currentStep++);
        _controller.forward();
      });
    } else {
      _controller.reverse().then((_) => widget.onComplete());
    }
  }

  void _skip() {
    _controller.reverse().then((_) => widget.onComplete());
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final size = MediaQuery.of(context).size;

    final spotlightX = (step.spotlightAlign.x + 1) / 2 * size.width;
    final spotlightY = (step.spotlightAlign.y + 1) / 2 * size.height;
    final isFab = step.spotlightRadius > 32;
    final isLast = _currentStep == _steps.length - 1;

    final tooltipTop = isFab ? spotlightY - 290 : spotlightY - 270;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _next,
          child: Stack(
            children: [
              CustomPaint(
                size: size,
                painter: _SpotlightPainter(
                  center: Offset(spotlightX, spotlightY),
                  radius: step.spotlightRadius,
                ),
              ),
              Positioned(
                top: tooltipTop.clamp(60.0, size.height - 340),
                left: 28,
                right: 28,
                child: _TooltipCard(
                  step: step,
                  currentStep: _currentStep,
                  totalSteps: _steps.length,
                  isLast: isLast,
                  onNext: _next,
                  onSkip: _skip,
                ),
              ),
              Positioned(
                left: spotlightX - step.spotlightRadius,
                top: spotlightY - step.spotlightRadius,
                child: _PulseRing(radius: step.spotlightRadius),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Spotlight Painter ─────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final Offset center;
  final double radius;

  _SpotlightPainter({required this.center, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.82);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius + 6))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    final glow = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, radius + 10, glow);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.center != center || old.radius != radius;
}

// ─── Tooltip Card ──────────────────────────────────────────────────────────

class _TooltipCard extends StatelessWidget {
  final OnboardingStep step;
  final int currentStep;
  final int totalSteps;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TooltipCard({
    required this.step,
    required this.currentStep,
    required this.totalSteps,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.14),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Icon(step.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                step.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                step.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  totalSteps,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == currentStep ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == currentStep
                          ? Colors.white
                          : Colors.white.withOpacity(0.25),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (!isLast)
                    Expanded(
                      child: GestureDetector(
                        onTap: onSkip,
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: GestureDetector(
                      onTap: onNext,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isLast ? 'Get Started' : 'Next',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pulse Ring ────────────────────────────────────────────────────────────

class _PulseRing extends StatefulWidget {
  final double radius;
  const _PulseRing({required this.radius});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final scale = 1.0 + _ctrl.value * 0.5;
        final opacity = (1.0 - _ctrl.value) * 0.4;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.radius * 2,
            height: widget.radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(opacity),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Contextual Guide Overlay ──────────────────────────────────────────────
// Reusable single-step spotlight used for contextual tips (first roll, At Lab).

class ContextualGuideOverlay extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Rect targetRect;
  final VoidCallback onDismiss;

  const ContextualGuideOverlay({
    Key? key,
    required this.title,
    required this.description,
    required this.icon,
    required this.targetRect,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<ContextualGuideOverlay> createState() => _ContextualGuideOverlayState();
}

class _ContextualGuideOverlayState extends State<ContextualGuideOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final center = widget.targetRect.center;
    final radius = widget.targetRect.longestSide / 2 + 8;
    final tooltipTop = (center.dy - 240).clamp(60.0, size.height - 300);

    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _dismiss,
          child: Stack(
            children: [
              CustomPaint(
                size: size,
                painter: _SpotlightPainter(center: center, radius: radius),
              ),
              Positioned(
                top: tooltipTop,
                left: 28,
                right: 28,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.14),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.icon, color: Colors.white, size: 32),
                          const SizedBox(height: 12),
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: _dismiss,
                            child: Container(
                              height: 44,
                              width: 160,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Got it',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
