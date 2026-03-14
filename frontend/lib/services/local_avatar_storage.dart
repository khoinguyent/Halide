import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Stores and retrieves the user's profile avatar on the local device.
/// Uses the app's documents directory so the file persists across launches.
class LocalAvatarStorage {
  static const String _avatarFileName = 'profile_avatar.jpg';

  /// Returns the full path where the avatar is stored, or null if not available (e.g. on web).
  static Future<String?> get avatarPath async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/$_avatarFileName';
    } catch (_) {
      return null;
    }
  }

  /// Saves the image at [sourcePath] to local app storage. Returns the saved path on success.
  static Future<String?> saveFromPath(String sourcePath) async {
    try {
      final path = await avatarPath;
      if (path == null) return null;
      final source = File(sourcePath);
      if (!await source.exists()) return null;
      await source.copy(path);
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Returns true if a locally stored avatar file exists.
  static Future<bool> get hasLocalAvatar async {
    try {
      final path = await avatarPath;
      if (path == null) return false;
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Removes the locally stored avatar file.
  static Future<void> remove() async {
    try {
      final path = await avatarPath;
      if (path != null) await File(path).delete();
    } catch (_) {}
  }
}
