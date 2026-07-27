import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../storage/secure_storage_service.dart';

/// Shared Dio HTTP client configured with [ApiConfig.baseUrl].
///
/// Does not define business endpoints. Auth header injection reads a stored
/// token when present; no login/API contracts are assumed.
class ApiClient {
  ApiClient({required this.secureStorage, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
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

  final Dio _dio;
  final SecureStorageService secureStorage;

  Dio get dio => _dio;
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(secureStorage: ref.watch(secureStorageServiceProvider));
});
