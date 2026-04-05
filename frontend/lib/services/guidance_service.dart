import 'package:shared_preferences/shared_preferences.dart';

/// Persists one-time Archive guidance for lab status, Drive link on the card, and sync after link.
class GuidanceService {
  GuidanceService._();
  static final GuidanceService instance = GuidanceService._();

  static const String _kAtLabGuidance = 'guidance_seen_at_lab_badge';
  static const String _kDriveUrlOnCardGuidance = 'guidance_seen_drive_url_on_card';
  static const String _kSyncAfterLinkGuidance = 'guidance_seen_sync_after_link';

  Future<bool> _read(String key) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(key) ?? false;
  }

  Future<void> _write(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, true);
  }

  Future<bool> get hasSeenAtLabGuidance async => _read(_kAtLabGuidance);

  Future<void> setAtLabGuidanceSeen() async => _write(_kAtLabGuidance);

  Future<bool> get hasSeenDriveUrlOnCardGuidance async => _read(_kDriveUrlOnCardGuidance);

  Future<void> setDriveUrlOnCardGuidanceSeen() async => _write(_kDriveUrlOnCardGuidance);

  Future<bool> get hasSeenSyncAfterLinkGuidance async => _read(_kSyncAfterLinkGuidance);

  Future<void> setSyncAfterLinkGuidanceSeen() async => _write(_kSyncAfterLinkGuidance);
}
