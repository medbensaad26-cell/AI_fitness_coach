import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_fitness_coach_mobile/core/network/api_client.dart';
import 'package:ai_fitness_coach_mobile/core/storage/memory_secure_storage_service.dart';
import 'package:ai_fitness_coach_mobile/features/programs/data/programs_repository.dart';

Map<String, dynamic> _sampleProgramJson({String id = 'p1'}) => {
      'id': id,
      'user_id': 'u1',
      'name': 'Strength Session',
      'goal': 'strength',
      'start_date': '2026-07-23',
      'end_date': '2026-07-30',
      'status': 'active',
      'exercises': [
        {
          'id': 'e1',
          'program_id': id,
          'exercise_name': 'Goblet Squat',
          'sets': 3,
          'reps': '8-10',
          'rest_seconds': 90,
          'duration_minutes': null,
          'notes': 'Brace core',
          'order': 0,
        },
      ],
    };

void main() {
  test('ProgramsRepository.listMine parses programs', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<List<dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: [_sampleProgramJson()],
            ),
          );
        },
      ),
    );

    final repository = ProgramsRepository(
      ApiClient(
        secureStorage: MemorySecureStorageService(),
        dio: dio,
      ),
    );

    final programs = await repository.listMine();
    expect(programs, hasLength(1));
    expect(programs.first.name, 'Strength Session');
    expect(programs.first.exercises.first.exerciseName, 'Goblet Squat');
  });

  test('ProgramsRepository.generate parses created program', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/api/programs/generate');
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 201,
              data: _sampleProgramJson(id: 'p-new'),
            ),
          );
        },
      ),
    );

    final repository = ProgramsRepository(
      ApiClient(
        secureStorage: MemorySecureStorageService(),
        dio: dio,
      ),
    );

    final program = await repository.generate();
    expect(program.id, 'p-new');
    expect(program.exercises, hasLength(1));
  });

  test('ProgramsRepository.suggestNext parses program and rationale', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/api/programs/suggest-next');
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 201,
              data: {
                'program': _sampleProgramJson(id: 'p-next'),
                'rationale': 'Progress from last session.',
                'adaptations': ['Added RDL', 'Lower fatigue volume'],
              },
            ),
          );
        },
      ),
    );

    final repository = ProgramsRepository(
      ApiClient(
        secureStorage: MemorySecureStorageService(),
        dio: dio,
      ),
    );

    final result = await repository.suggestNext();
    expect(result.program.id, 'p-next');
    expect(result.rationale, 'Progress from last session.');
    expect(result.adaptations, hasLength(2));
  });
}
