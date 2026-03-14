/// App configuration — updated automatically by the tester.
/// Uses localhost by default; override with --dart-define=BASE_URL=... at build/run time.
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  static const String apiUrl = '$baseUrl/api/v1';
  static const String authUrl = baseUrl; // Root for /login, /register
  static const String graphqlUrl = '$baseUrl/graphql';
}
