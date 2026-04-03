import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';
import '../models/notification_model.dart';

/// A global key to access the ScaffoldMessenger from anywhere in the app.
/// @deprecated: Use [notificationProvider] instead.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Legacy utility for non-Riverpod areas. 
/// NOTE: This only works if you have access to a [WidgetRef].
/// Most calls have been refactored to ref.read(notificationProvider.notifier).show()
void showHalideSnackBar(String message, {NotificationType type = NotificationType.info}) {
  debugPrint('[Halide] Legacy showHalideSnackBar called: $message');
  // Since we cannot easily access ref here without a context or global container,
  // we encourage using the provider directly in widgets.
}
