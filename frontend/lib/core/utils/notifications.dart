import 'package:flutter/material.dart';

/// A global key to access the ScaffoldMessenger from anywhere in the app.
/// This allows showing SnackBars that correctly push the global FAB in the shell.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showHalideSnackBar(String message, {Color backgroundColor = Colors.orange}) {
  scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Push above the glass dock (approx 88-100px)
    ),
  );
}
