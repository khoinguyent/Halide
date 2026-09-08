import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/l10n_extension.dart';
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

  final l10n = context.l10n;
  final go = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1a1a1e),
      title: Text(
        l10n.connectGoogleDriveTitle,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
      content: Text(
        l10n.connectGoogleDriveBody,
        style: const TextStyle(color: Colors.white70, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancelUpper),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.connectGoogleUpper),
        ),
      ],
    ),
  );

  if (go != true || !context.mounted) return false;

  try {
    await StorageConnectionService().connectGoogleDrive();
    if (context.mounted) {
      ref.read(notificationProvider.notifier).show(
            context.l10n.googleDriveConnected,
            type: NotificationType.success,
          );
    }
    return true;
  } on StorageConnectionException catch (e) {
    if (context.mounted) {
      ref.read(notificationProvider.notifier).show(
            e.message,
            type: NotificationType.error,
          );
    }
    return false;
  } catch (e) {
    if (context.mounted) {
      ref.read(notificationProvider.notifier).show(
            context.l10n.couldNotConnectGoogleDrive,
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

/// Older Drive connections may lack `drive.file` write scope. Prompts the user to
/// disconnect + reconnect so Agxel Vault backup can create folders / upload files.
Future<bool> promptReconnectGoogleDriveForVault(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!context.mounted) return false;

  final go = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1a1a1e),
      title: const Text(
        'Reconnect Google Drive',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
      content: const Text(
        'Your Google Drive connection needs updated permissions to back up rolls '
        'to Agxel Vault. Reconnect Drive once, then try backup again.',
        style: TextStyle(color: Colors.white70, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(context.l10n.cancelUpper),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('RECONNECT'),
        ),
      ],
    ),
  );

  if (go != true || !context.mounted) return false;

  try {
    final api = ApiService();
    final resp = await api.get('/api/v1/connections');
    final raw = resp.data;
    if (raw is List) {
      for (final item in raw) {
        if (item is Map && (item['provider'] as String?) == 'gdrive') {
          final id = item['id']?.toString();
          if (id != null && id.isNotEmpty) {
            await api.delete('/api/v1/connections/$id');
          }
        }
      }
    }

    await StorageConnectionService().connectGoogleDrive();
    if (context.mounted) {
      ref.read(notificationProvider.notifier).show(
            'Google Drive reconnected — try backup again.',
            type: NotificationType.success,
          );
    }
    return true;
  } on StorageConnectionException catch (e) {
    if (context.mounted) {
      ref.read(notificationProvider.notifier).show(
            e.message,
            type: NotificationType.error,
          );
    }
    return false;
  } catch (e) {
    if (context.mounted) {
      ref.read(notificationProvider.notifier).show(
            context.l10n.couldNotConnectGoogleDrive,
            type: NotificationType.error,
          );
    }
    return false;
  } finally {
    dismissKeyboardGlobally();
  }
}
