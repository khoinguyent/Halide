import 'package:flutter/foundation.dart';

import 'env_loader.dart';

enum AppFlavor { dev, staging, prod }

/// App configuration.
///
/// **FLAVOR** resolution order:
/// 1. Non-empty `--dart-define=FLAVOR=...` (wins so `flutter run --dart-define=FLAVOR=staging`
///    hits staging even if `.env` still says `dev`).
/// 2. Non-empty `FLAVOR` in bundled `frontend/.env`.
/// 3. Default **`staging`** (shared staging API, not localhost).
class AppConfig {
  static String get _flavor {
    const fromDefine = String.fromEnvironment('FLAVOR', defaultValue: '');
    if (fromDefine.trim().isNotEmpty) {
      return fromDefine.trim();
    }
    return halideEnvString('FLAVOR', fromDefine: 'staging');
  }

  static AppFlavor get flavor {
    if (_flavor == 'prod') return AppFlavor.prod;
    if (_flavor == 'staging') return AppFlavor.staging;
    return AppFlavor.dev;
  }

  /// In-app diagnostics: debug logs, image URL inspector, etc.
  /// Enabled for **dev** & **staging** flavors and for **debug** builds; **off** for release **prod**.
  static bool get showInAppDiagnostics {
    if (kDebugMode) return true;
    return flavor != AppFlavor.prod;
  }

  static const String _prodUrl = 'https://api.smartconnector.io.vn';
  static const String _stagingUrl = 'https://stagging-api.smartconnector.io.vn';
  static const String _devUrl = 'http://localhost:8000';

  static String get baseUrl => _flavor == 'prod'
      ? _prodUrl
      : _flavor == 'staging'
          ? _stagingUrl
          : _devUrl;

  static String get apiUrl => '$baseUrl/api/v1';
  static String get authUrl => baseUrl;
  static String get graphqlUrl => '$baseUrl/graphql';

  /// Public marketing / legal pages (App Store review: Privacy + Terms links on paywall).
  static const String privacyPolicyWebUrl = 'https://www.halide.io.vn/privacy';

  /// Apple standard EULA for licensed applications (Terms of Use link on subscription UI).
  static const String appleStandardEulaUrl =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
}
