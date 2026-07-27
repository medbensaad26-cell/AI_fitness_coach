/// Application API configuration.
///
/// Override at build/run time with:
/// `--dart-define=API_BASE_URL=https://example.com`
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
