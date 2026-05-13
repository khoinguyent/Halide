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
      return FadeTransition(opacity: animation, child: child);
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
    final viewInsets = MediaQuery.of(context).viewInsets;
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
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
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
        // Dialog content - Keyboard aware with scrolling support
        Padding(
          padding: EdgeInsets.only(
            bottom: viewInsets.bottom,
            top:
                MediaQuery.of(context).padding.top +
                16, // Ensure title doesn't hide under status bar
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    // Limit height to available area minus the nav bar and some margin
                    maxHeight: constraints.maxHeight - navBarHeight - 16,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: child,
                  ),
                ),
              );
            },
          ),
        ),
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
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
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

/// A standardized high-transparency glass container for modals and dialogs.
class HalideModalContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final bool hasInnerBorder;

  const HalideModalContainer({
    Key? key,
    required this.child,
    this.borderRadius = 32,
    this.padding = const EdgeInsets.all(32),
    this.hasInnerBorder = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width * 0.9,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(borderRadius),
                border: hasInnerBorder
                    ? Border.all(color: Colors.white.withOpacity(0.07))
                    : null,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A minimalist premium text field with underline border and uppercase labels.
class HalideTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final int maxLines;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final String? initialValue;

  const HalideTextField({
    Key? key,
    this.controller,
    this.initialValue,
    required this.label,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.errorText,
    this.onChanged,
    this.onTap,
    this.maxLines = 1,
    this.focusNode,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onTap: onTap,
      maxLines: maxLines,
      focusNode: focusNode,
      validator: validator,
      cursorColor: Colors.white,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        letterSpacing: 0.5,
      ),
      decoration: InputDecoration(
        labelText: label.toUpperCase(),
        errorText: errorText,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.35),
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: Colors.white24, size: 18)
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 1.2),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(
          color: Colors.redAccent,
          fontSize: 10,
          height: 1.2,
        ),
      ),
    );
  }
}

/// A standardized action button (White/Black) for modals.
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          disabledBackgroundColor: Colors.white.withOpacity(0.5),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.black54,
                ),
              )
            : Text(
                text.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
      ),
    );
  }
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
    return HalideModalContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          HalideActionButton(
            text: buttonText,
            onPressed: onButtonPressed ?? () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
