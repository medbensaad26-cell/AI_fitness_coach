import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_fitness_coach_mobile/core/network/api_client.dart';
import 'package:ai_fitness_coach_mobile/core/storage/memory_secure_storage_service.dart';
import 'package:ai_fitness_coach_mobile/features/profile/data/profile_models.dart';
import 'package:ai_fitness_coach_mobile/features/profile/data/profile_repository.dart';

Map<String, dynamic> _sampleProfileJson({
  String name = 'Alex',
  int availableTimeMinutes = 45,
}) =>
    {
      'id': 'u1',
      'email': 'alex@example.com',
      'name': name,
      'age': 28,
      'sex': 'female',
      'height_cm': 170.0,
      'weight_kg': 65.0,
      'fitness_level': 'intermediate',
      'primary_goal': 'strength',
      'training_frequency': '3x/week',
      'available_equipment': 'dumbbells',
      'limitations': 'none',
      'available_time_minutes': availableTimeMinutes,
      'created_at': '2026-01-01',
      'updated_at': '2026-07-23',
    };

void main() {
  test('ProfileRepository.getMine parses profile response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.method, 'GET');
          expect(options.path, '/api/me/profile');
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: _sampleProfileJson(),
            ),
          );
        },
      ),
    );

    final repository = ProfileRepository(
      ApiClient(
        secureStorage: MemorySecureStorageService(),
        dio: dio,
      ),
    );

    final profile = await repository.getMine();
    expect(profile.id, 'u1');
    expect(profile.email, 'alex@example.com');
    expect(profile.name, 'Alex');
    expect(profile.availableTimeMinutes, 45);
    expect(profile.primaryGoal, 'strength');
  });

  test('ProfileRepository.updateMine sends patch and parses response',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.method, 'PATCH');
          expect(options.path, '/api/me/profile');
          expect(options.data, isA<Map>());
          final body = options.data as Map;
          expect(body['available_time_minutes'], 60);
          expect(body['primary_goal'], 'hypertrophy');
          expect(body.containsKey('name'), isFalse);

          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: _sampleProfileJson(
                name: 'Alex',
                availableTimeMinutes: 60,
              )..['primary_goal'] = 'hypertrophy',
            ),
          );
        },
      ),
    );

    final repository = ProfileRepository(
      ApiClient(
        secureStorage: MemorySecureStorageService(),
        dio: dio,
      ),
    );

    final profile = await repository.updateMine(
      const ProfileUpdate(
        availableTimeMinutes: 60,
        primaryGoal: 'hypertrophy',
      ),
    );

    expect(profile.availableTimeMinutes, 60);
    expect(profile.primaryGoal, 'hypertrophy');
  });

  test('ProfileUpdate.toJson omits unset fields', () {
    const update = ProfileUpdate(name: 'Sam', age: 30);
    expect(update.toJson(), {'name': 'Sam', 'age': 30});
  });
}
