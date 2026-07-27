import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../storage/secure_storage_service.dart';

/// Shared Dio HTTP client configured with [ApiConfig.baseUrl].
///
/// Default timeouts are short for normal CRUD. AI routes override with longer
/// receive timeouts (first generate may download embedding models).
class ApiClient {
  ApiClient({required this.secureStorage, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 20),
              headers: const {
                Headers.contentTypeHeader: Headers.jsonContentType,
                Headers.acceptHeader: Headers.jsonContentType,
              },
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await secureStorage.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  /// Extra-long timeouts for AI endpoints (generate / coach).
  static const Duration aiReceiveTimeout = Duration(minutes: 3);

  final Dio _dio;
  final SecureStorageService secureStorage;

  Dio get dio => _dio;
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(secureStorage: ref.watch(secureStorageServiceProvider));
});
