import 'dart:ui';
import 'package:flutter/material.dart';

/// Height reserved at the bottom so the nav bar stays unblurred when a modal is open.
const double kHalideModalNavBarReservedHeight = 100.0;

/// Shows a dialog with a blurred barrier over the content area only;
/// the bottom [kHalideModalNavBarReservedHeight] (menu bar) is not blurred.
Future<T?> showHalideDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Halide dialog barrier',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return _HalideDialogBarrier(
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor ?? Colors.black.withOpacity(0.4),
        child: builder(context),
      );
    },
  );
}

class _HalideDialogBarrier extends StatelessWidget {
  final bool barrierDismissible;
  final Color barrierColor;
  final Widget child;

  const _HalideDialogBarrier({
    required this.barrierDismissible,
    required this.barrierColor,
    required this.child,
  });

  void _onBarrierTap(BuildContext context) {
    if (barrierDismissible) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final navBarHeight = kHalideModalNavBarReservedHeight + bottomPadding;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred area: content only (above the menu bar)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: navBarHeight,
          child: GestureDetector(
            onTap: barrierDismissible ? () => _onBarrierTap(context) : null,
            behavior: HitTestBehavior.opaque,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(color: barrierColor),
              ),
            ),
          ),
        ),
        // Menu bar strip: dim only, no blur (so nav bar stays sharp)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: navBarHeight,
          child: GestureDetector(
            onTap: barrierDismissible ? () => _onBarrierTap(context) : null,
            behavior: HitTestBehavior.opaque,
            child: Container(color: barrierColor),
          ),
        ),
        // Dialog content
        Center(child: child),
      ],
    );
  }
}

/// Shows a modal bottom sheet with the same blurred barrier (content area only;
/// menu bar stays unblurred).
Future<T?> showHalideModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  Color? backgroundColor,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    barrierLabel: 'Halide bottom sheet barrier',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      final sheetContent = builder(context);
      return _HalideDialogBarrier(
        barrierDismissible: isDismissible,
        barrierColor: Colors.black.withOpacity(0.4),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: backgroundColor ?? Colors.transparent,
            child: sheetContent,
          ),
        ),
      );
    },
  );
}
