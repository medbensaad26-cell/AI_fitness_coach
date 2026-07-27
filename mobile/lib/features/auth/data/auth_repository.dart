import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_error_mapper.dart';
import 'auth_models.dart';

/// Auth API calls — login and register only.
class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Dio get _dio => _apiClient.dio;

  Future<TokenResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/login',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedException('Empty login response');
      }
      return TokenResponse.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<void> register(RegisterRequest request) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/register',
        data: request.toJson(),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
