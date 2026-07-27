import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_error_mapper.dart';
import 'program_models.dart';

/// Program list / detail / AI generate API.
class ProgramsRepository {
  ProgramsRepository(this._apiClient);

  final ApiClient _apiClient;

  Dio get _dio => _apiClient.dio;

  Future<List<Program>> listMine() async {
    try {
      final response = await _dio.get<dynamic>('/api/me/programs');
      final data = response.data;
      if (data is! List) {
        throw const UnexpectedException('Unexpected programs response');
      }
      return data
          .map((item) => Program.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Program> getById(String programId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/programs/$programId',
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedException('Empty program response');
      }
      return Program.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Program> generate({DateTime? startDate}) async {
    try {
      final body = <String, dynamic>{};
      if (startDate != null) {
        body['start_date'] =
            '${startDate.year.toString().padLeft(4, '0')}-'
            '${startDate.month.toString().padLeft(2, '0')}-'
            '${startDate.day.toString().padLeft(2, '0')}';
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/programs/generate',
        data: body,
        options: Options(
          receiveTimeout: ApiClient.aiReceiveTimeout,
          sendTimeout: ApiClient.aiReceiveTimeout,
        ),
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedException('Empty generate response');
      }
      return Program.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<SuggestNextResult> suggestNext({DateTime? startDate}) async {
    try {
      final body = <String, dynamic>{};
      if (startDate != null) {
        body['start_date'] =
            '${startDate.year.toString().padLeft(4, '0')}-'
            '${startDate.month.toString().padLeft(2, '0')}-'
            '${startDate.day.toString().padLeft(2, '0')}';
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/programs/suggest-next',
        data: body,
        options: Options(
          receiveTimeout: ApiClient.aiReceiveTimeout,
          sendTimeout: ApiClient.aiReceiveTimeout,
        ),
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedException('Empty suggest-next response');
      }
      return SuggestNextResult.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}

final programsRepositoryProvider = Provider<ProgramsRepository>((ref) {
  return ProgramsRepository(ref.watch(apiClientProvider));
});
