import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads key/value pairs from the bundled `.env` asset (see `pubspec.yaml`).
/// Call from [main] before [PurchaseService.init] and any code that reads [AppConfig].
Future<void> loadHalideEnv() async {
  try {
    await dotenv.load(fileName: '.env');
    if (kDebugMode) {
      debugPrint('[Env] Loaded .env (${dotenv.env.length} keys)');
    }
  } catch (e, st) {
    debugPrint('[Env] Failed to load .env asset: $e\n$st');
    debugPrint(
      '[Env] Ensure `frontend/.env` exists (e.g. `cp .env.example .env`) '
      'or pass --dart-define=KEY=value for FLAVOR, keys, etc.',
    );
  }
}

/// Prefer value from [dotenv] when non-empty; otherwise compile-time --dart-define.
String halideEnvString(String key, {required String fromDefine}) {
  final raw = dotenv.env[key];
  if (raw != null) {
    final t = raw.trim();
    if (t.isNotEmpty) return t;
  }
  return fromDefine;
}
