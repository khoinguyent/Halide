import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Persists one-time Archive guidance for lab status, Drive link on the card, and sync after link.
///
/// Keys are scoped by [AppFlavor] so switching between dev / staging / prod backends does not
/// reuse "already seen" state from another environment on the same install.
class GuidanceService {
  GuidanceService._();
  static final GuidanceService instance = GuidanceService._();

  String get _kAtLabGuidance => 'guidance_${AppConfig.flavor.name}_seen_at_lab_badge';
  String get _kDriveUrlOnCardGuidance => 'guidance_${AppConfig.flavor.name}_seen_drive_url_on_card';
  String get _kSyncAfterLinkGuidance => 'guidance_${AppConfig.flavor.name}_seen_sync_after_link';
  String get _kNewRollShootingIntro => 'guidance_${AppConfig.flavor.name}_seen_new_roll_shooting_intro';
  String get _kMeterIntro => 'guidance_${AppConfig.flavor.name}_seen_meter_intro';

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

  /// Three-step Archive intro after creating a roll: status, EXIF log, shot log.
  Future<bool> get hasSeenNewRollShootingIntro async => _read(_kNewRollShootingIntro);

  Future<void> setNewRollShootingIntroSeen() async => _write(_kNewRollShootingIntro);

  /// Short Precision Meter tab intro (Pro).
  Future<bool> get hasSeenMeterIntro async => _read(_kMeterIntro);

  Future<void> setMeterIntroSeen() async => _write(_kMeterIntro);

  /// Print compose: stamp drag / pinch / lock intro.
  String get _kPrintStampIntro => 'guidance_${AppConfig.flavor.name}_seen_print_stamp_intro';

  Future<bool> get hasSeenPrintStampIntro async => _read(_kPrintStampIntro);

  Future<void> setPrintStampIntroSeen() async => _write(_kPrintStampIntro);

  /// Gyro Scan HUD: preview mode toggle (negative vs positive).
  String get _kGyroScanIntro => 'guidance_${AppConfig.flavor.name}_seen_gyro_scan_intro';

  Future<bool> get hasSeenGyroScanIntro async => _read(_kGyroScanIntro);

  Future<void> setGyroScanIntroSeen() async => _write(_kGyroScanIntro);

  /// Archive: personal Drive backup via the cloud-upload app bar icon.
  String get _kPersonalDriveBackupGuidance =>
      'guidance_${AppConfig.flavor.name}_seen_personal_drive_backup';

  Future<bool> get hasSeenPersonalDriveBackupGuidance async =>
      _read(_kPersonalDriveBackupGuidance);

  Future<void> setPersonalDriveBackupGuidanceSeen() async =>
      _write(_kPersonalDriveBackupGuidance);
}
