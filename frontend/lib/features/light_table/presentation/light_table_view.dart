import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../logic/light_table_color.dart';
import '../services/light_table_hardware_controller.dart';
import 'widgets/alignment_grid_overlay.dart';
import 'widgets/light_table_control_bar.dart';
import 'widgets/touch_shield_overlay.dart';

export '../logic/light_table_color.dart';
export '../services/light_table_hardware_controller.dart';

/// Full-screen calibrated light box for flat-lay negative scanning.
///
/// Drop into any route via [LightTableView] or navigate to `/light-table`.
class LightTableView extends StatefulWidget {
  const LightTableView({super.key});

  @override
  State<LightTableView> createState() => _LightTableViewState();
}

class _LightTableViewState extends State<LightTableView>
    with TickerProviderStateMixin {
  final LightTableHardwareController _hardware = LightTableHardwareController();

  double _kelvin = LightTableTokens.kelvinDefault;
  bool _gridVisible = true;
  bool _isLocked = false;
  double _controlsOpacity = 1.0;

  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    unawaited(_hardware.activate());
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    unawaited(_hardware.deactivate());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_isLocked) return;

    _idleTimer = Timer(LightTableTokens.controlsIdleTimeout, () {
      if (!mounted || _isLocked) return;
      setState(() => _controlsOpacity = 0.0);
    });
  }

  void _revealControls() {
    if (_isLocked) return;
    setState(() => _controlsOpacity = 1.0);
    _resetIdleTimer();
  }

  void _onInteraction() {
    _revealControls();
  }

  void _onKelvinChanged(double value) {
    setState(() => _kelvin = value);
    _onInteraction();
  }

  void _toggleGrid() {
    setState(() => _gridVisible = !_gridVisible);
    _onInteraction();
  }

  void _engageLock() {
    _idleTimer?.cancel();
    setState(() {
      _isLocked = true;
      _controlsOpacity = 0.0;
    });
  }

  void _disengageLock() {
    setState(() => _isLocked = false);
    _revealControls();
  }

  @override
  Widget build(BuildContext context) {
    final backdropColor = getColorFromTemperature(_kelvin);

    return PopScope(
      canPop: !_isLocked,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isLocked) {
          HapticFeedback.lightImpact();
        }
      },
      child: Scaffold(
        backgroundColor: backdropColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: backdropColor),
            if (_gridVisible)
              const Positioned.fill(child: AlignmentGridOverlay()),
            if (!_isLocked)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _revealControls,
                  onPanDown: (_) => _onInteraction(),
                  child: const SizedBox.expand(),
                ),
              ),
            if (!_isLocked)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + 12,
                child: IgnorePointer(
                  ignoring: _controlsOpacity == 0.0,
                  child: AnimatedOpacity(
                    opacity: _controlsOpacity,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    child: LightTableControlBar(
                      kelvin: _kelvin,
                      gridVisible: _gridVisible,
                      onKelvinChanged: _onKelvinChanged,
                      onToggleGrid: _toggleGrid,
                      onLockScreen: _engageLock,
                    ),
                  ),
                ),
              ),
            if (_isLocked)
              Positioned.fill(
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: AbsorbPointer(
                        child: SizedBox.expand(),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: MediaQuery.paddingOf(context).bottom + 28,
                      child: Center(
                        child: TouchShieldOverlay(
                          onUnlocked: _disengageLock,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_isLocked)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 8,
                child: AnimatedOpacity(
                  opacity: _controlsOpacity,
                  duration: const Duration(milliseconds: 350),
                  child: _CloseButton(onPressed: () => context.pop()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LightTableTokens.zinc900.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.close_rounded,
            color: Colors.white.withValues(alpha: 0.85),
            size: 22,
          ),
        ),
      ),
    );
  }
}
