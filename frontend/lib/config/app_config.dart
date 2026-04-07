import 'package:flutter/foundation.dart';

import 'env_loader.dart';

enum AppFlavor { dev, staging, prod }

/// App configuration.
/// Loads [FLAVOR] from bundled `frontend/.env` first, then `--dart-define=FLAVOR=...`.
class AppConfig {
  static String get _flavor {
    return halideEnvString(
      'FLAVOR',
      fromDefine: const String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
    );
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
}
