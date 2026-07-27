import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_fitness_coach_mobile/core/network/api_client.dart';
import 'package:ai_fitness_coach_mobile/core/storage/memory_secure_storage_service.dart';
import 'package:ai_fitness_coach_mobile/features/sessions/data/sessions_repository.dart';

Map<String, dynamic> _sampleSessionJson({String id = 's1'}) => {
      'id': id,
      'user_id': 'u1',
      'program_id': 'p1',
      'start_time': '2026-07-23T10:00:00Z',
      'end_time': '2026-07-23T10:45:00Z',
      'duration_minutes': 45,
      'overall_feeling': 4,
      'fatigue_level': 3,
      'comments': 'Solid session',
      'created_at': '2026-07-23T10:45:00Z',
      'exercises': [
        {
          'id': 'ex1',
          'session_id': id,
          'exercise_name': 'Goblet Squat',
          'sets_completed': 3,
          'reps_completed': '8',
          'weight_kg': 20.0,
          'difficulty': 3,
          'skipped': false,
          'notes': 'Felt strong',
        },
        {
          'id': 'ex2',
          'session_id': id,
          'exercise_name': 'Push-up',
          'sets_completed': 0,
          'reps_completed': null,
          'weight_kg': null,
          'difficulty': null,
          'skipped': true,
          'notes': null,
        },
      ],
    };

void main() {
  test('SessionsRepository.getById parses session detail', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.method, 'GET');
          expect(options.path, '/api/sessions/s1');
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: _sampleSessionJson(),
            ),
          );
        },
      ),
    );

    final repository = SessionsRepository(
      ApiClient(
        secureStorage: MemorySecureStorageService(),
        dio: dio,
      ),
    );

    final session = await repository.getById('s1');
    expect(session.id, 's1');
    expect(session.programId, 'p1');
    expect(session.durationMinutes, 45);
    expect(session.overallFeeling, 4);
    expect(session.comments, 'Solid session');
    expect(session.exercises, hasLength(2));
    expect(session.exercises.first.exerciseName, 'Goblet Squat');
    expect(session.exercises.first.weightKg, 20.0);
    expect(session.exercises.last.skipped, isTrue);
  });
}
