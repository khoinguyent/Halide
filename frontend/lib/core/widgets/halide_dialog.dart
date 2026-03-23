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
class HalideSimpleDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback? onButtonPressed;

  const HalideSimpleDialog({
    Key? key,
    required this.title,
    required this.message,
    this.buttonText = 'OK',
    this.onButtonPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C29),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: onButtonPressed ?? () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.95),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class HalideModalContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final bool hasInnerBorder;
  final EdgeInsets padding;

  const HalideModalContainer({
    Key? key,
    required this.child,
    this.borderRadius = 24,
    this.hasInnerBorder = true,
    this.padding = const EdgeInsets.all(24),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width * 0.9,
        padding: padding,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C29),
          borderRadius: BorderRadius.circular(borderRadius),
          border: hasInnerBorder ? Border.all(color: Colors.white.withOpacity(0.12)) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class HalideTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const HalideTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.white70, size: 20) : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}

class HalideActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double height;

  const HalideActionButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = 56,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
              )
            : Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1),
              ),
      ),
    );
  }
}
