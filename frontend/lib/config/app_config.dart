import 'package:flutter/foundation.dart';

enum AppFlavor { dev, staging, prod }

/// App configuration.
/// Defaults to production domain in Release mode, and localhost in Debug mode.
/// Can be overridden with --dart-define=BASE_URL=... or --dart-define=FLAVOR=...
class AppConfig {
  static const String _flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  static AppFlavor get flavor {
    if (_flavor == 'prod') return AppFlavor.prod;
    if (_flavor == 'staging') return AppFlavor.staging;
    return AppFlavor.dev;
  }

  static const String _prodUrl = 'https://api.smartconnector.io.vn';
  static const String _stagingUrl = 'https://stagging-api.smartconnector.io.vn';
  static const String _devUrl = 'http://localhost:8000';

  static const String baseUrl = _flavor == 'prod' ? _prodUrl
                             : _flavor == 'staging' ? _stagingUrl
                             : _devUrl;

  static const String apiUrl = '$baseUrl/api/v1';
  static const String authUrl = baseUrl;
  static const String graphqlUrl = '$baseUrl/graphql';
}
