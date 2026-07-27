import 'package:flutter/foundation.dart';

/// Application API configuration.
///
/// Override at build/run time with:
/// `--dart-define=API_BASE_URL=https://example.com`
class ApiConfig {
  ApiConfig._();

  static const String _fromEnvironment = String.fromEnvironment('API_BASE_URL');

  /// Android emulator reaches the host via `10.0.2.2`; desktop/iOS/web use localhost.
  static String get baseUrl {
    if (_fromEnvironment.isNotEmpty) return _fromEnvironment;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }
}
