/// App configuration — updated automatically by the tester.
/// Replace BASE_URL with the active Cloudflare Tunnel URL for testing.
class AppConfig {
  static const String baseUrl = 'https://encoding-hour-images-coupled.trycloudflare.com';
  static const String apiUrl = '$baseUrl/api/v1';
  static const String authUrl = baseUrl; // Root for /login, /register
  static const String graphqlUrl = '$baseUrl/graphql';
}
