import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/notification_model.dart';
import '../core/providers/notification_provider.dart';
import 'api_service.dart';
import 'storage_connection_service.dart';

/// Returns true if `/api/v1/connections` includes a Google Drive credential.
Future<bool> isGoogleDriveConnected(ApiService api) async {
  try {
    final resp = await api.get('/api/v1/connections');
    final raw = resp.data;
    if (raw is! List) return false;
    for (final item in raw) {
      if (item is Map && (item['provider'] as String?) == 'gdrive') {
        return true;
      }
    }
  } catch (_) {}
  return false;
}

/// Dismisses the on-screen keyboard (e.g. after Google OAuth returns to the app).
void dismissKeyboardGlobally() {
  FocusManager.instance.primaryFocus?.unfocus();
}

/// If Drive is not connected, prompts the user and runs [StorageConnectionService.connectGoogleDrive].
/// Returns true when Drive is ready to use, false if cancelled or connection failed.
Future<bool> ensureGoogleDriveConnected(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
  final api = ApiService();
  if (await isGoogleDriveConnected(api)) {
    return true;
  }
  if (!context.mounted) return false;

  final go = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1a1a1e),
      title: const Text(
        'CONNECT GOOGLE DRIVE',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
      content: const Text(
        'To import photos from a shared Drive link, Halide needs access to your Google account '
        '(read-only). Connect once in Settings, or tap Connect below.',
        style: TextStyle(color: Colors.white70, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('CONNECT GOOGLE'),
        ),
      ],
    ),
  );

  if (go != true || !context.mounted) return false;

  try {
    await StorageConnectionService().connectGoogleDrive();
    if (context.mounted) {
      ref.read(notificationProvider.notifier).show(
            'GOOGLE DRIVE CONNECTED.',
            type: NotificationType.success,
          );
    }
    return true;
  } on StorageConnectionException catch (e) {
    if (context.mounted) {
      ref.read(notificationProvider.notifier).show(
            e.message.toUpperCase(),
            type: NotificationType.error,
          );
    }
    return false;
  } catch (e) {
    if (context.mounted) {
      ref.read(notificationProvider.notifier).show(
            'COULD NOT CONNECT GOOGLE DRIVE.',
            type: NotificationType.error,
          );
    }
    return false;
  }
  } finally {
    dismissKeyboardGlobally();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      dismissKeyboardGlobally();
    });
  }
}
