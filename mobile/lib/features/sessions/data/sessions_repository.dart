import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_error_mapper.dart';
import 'session_models.dart';

class CoachRepository {
  CoachRepository(this._apiClient);

  final ApiClient _apiClient;

  Dio get _dio => _apiClient.dio;

  Options get _aiOptions => Options(
    receiveTimeout: ApiClient.aiReceiveTimeout,
    sendTimeout: const Duration(seconds: 30),
  );

  Future<CoachStartResult> start({String? programId}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/coach/start',
        data: {
          'program_id': ?programId,
        },
        options: _aiOptions,
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedException('Empty coach start response');
      }
      return CoachStartResult.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<CoachAfterExerciseResult> afterExercise({
    required String exerciseName,
    required int setsCompleted,
    String? programId,
    String? repsCompleted,
    double? weightKg,
    int? difficulty,
    bool skipped = false,
    String? notes,
    String? userMessage,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/coach/after-exercise',
        data: {
          'program_id': ?programId,
          'exercise_name': exerciseName,
          'sets_completed': setsCompleted,
          'reps_completed': repsCompleted,
          'weight_kg': weightKg,
          'difficulty': difficulty,
          'skipped': skipped,
          'notes': notes,
          'user_message': userMessage,
        },
        options: _aiOptions,
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedException('Empty after-exercise response');
      }
      return CoachAfterExerciseResult.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<CoachMidSessionResult> midSession({
    required String userMessage,
    int? readiness,
    List<SessionExerciseFeedback> recentFeedback = const [],
    Map<String, dynamic>? currentExercise,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/coach/mid-session',
        data: {
          'user_message': userMessage,
          'readiness': readiness,
          'recent_feedback':
              recentFeedback.map((item) => item.toJson()).toList(),
          'current_exercise': currentExercise,
          'upcoming_exercises': <Map<String, dynamic>>[],
        },
        options: _aiOptions,
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedException('Empty mid-session response');
      }
      return CoachMidSessionResult.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<CoachEndResult> end({
    required List<SessionExerciseFeedback> exercises,
    int? overallFeeling,
    int? fatigueLevel,
    String? comments,
    int? durationMinutes,
    String? userMessage,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/coach/end',
        data: {
          'overall_feeling': overallFeeling,
          'fatigue_level': fatigueLevel,
          'comments': comments,
          'duration_minutes': durationMinutes,
          'user_message': userMessage,
          'exercises': exercises.map((item) => item.toJson()).toList(),
        },
        options: _aiOptions,
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedException('Empty coach end response');
      }
      return CoachEndResult.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}

class SessionsRepository {
  SessionsRepository(this._apiClient);

  final ApiClient _apiClient;

  Dio get _dio => _apiClient.dio;

  Future<WorkoutSession> create(SessionCreateRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/sessions',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedException('Empty session response');
      }
      return WorkoutSession.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<List<WorkoutSession>> listMine({int limit = 20}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/me/sessions',
        queryParameters: {'limit': limit},
      );
      final data = response.data;
      if (data is! List) {
        throw const UnexpectedException('Unexpected sessions response');
      }
      return data
          .map((item) => WorkoutSession.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<WorkoutSession> getById(String sessionId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/sessions/$sessionId',
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedException('Empty session response');
      }
      return WorkoutSession.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}

final coachRepositoryProvider = Provider<CoachRepository>((ref) {
  return CoachRepository(ref.watch(apiClientProvider));
});

final sessionsRepositoryProvider = Provider<SessionsRepository>((ref) {
  return SessionsRepository(ref.watch(apiClientProvider));
});
