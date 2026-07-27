import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_fitness_coach_mobile/core/errors/app_exception.dart';
import 'package:ai_fitness_coach_mobile/core/network/api_client.dart';
import 'package:ai_fitness_coach_mobile/core/network/dio_error_mapper.dart';
import 'package:ai_fitness_coach_mobile/core/storage/memory_secure_storage_service.dart';
import 'package:ai_fitness_coach_mobile/features/auth/data/auth_models.dart';
import 'package:ai_fitness_coach_mobile/features/auth/data/auth_repository.dart';

void main() {
  test('AuthRepository.login parses token response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'access_token': 'jwt-abc',
                'token_type': 'bearer',
              },
            ),
          );
        },
      ),
    );

    final repository = AuthRepository(
      ApiClient(
        secureStorage: MemorySecureStorageService(),
        dio: dio,
      ),
    );

    final token = await repository.login(
      const LoginRequest(email: 'a@b.com', password: 'secret'),
    );
    expect(token.accessToken, 'jwt-abc');
  });

  test('AuthRepository.login maps 401 into AppException', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 401,
                data: {'detail': 'Invalid email or password'},
              ),
            ),
          );
        },
      ),
    );

    final repository = AuthRepository(
      ApiClient(
        secureStorage: MemorySecureStorageService(),
        dio: dio,
      ),
    );

    expect(
      () => repository.login(
        const LoginRequest(email: 'a@b.com', password: 'wrong'),
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.message,
          'message',
          'Invalid email or password',
        ),
      ),
    );
  });

  test('mapDioException maps connection errors to NetworkException', () {
    final mapped = mapDioException(
      DioException(
        requestOptions: RequestOptions(path: '/api/login'),
        type: DioExceptionType.connectionError,
      ),
    );
    expect(mapped, isA<NetworkException>());
  });
}
