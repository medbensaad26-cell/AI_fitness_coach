import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_error_mapper.dart';
import 'profile_models.dart';

/// Profile read / partial update API.
class ProfileRepository {
  ProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  Dio get _dio => _apiClient.dio;

  Future<UserProfile> getMine() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/me/profile');
      final data = response.data;
      if (data == null) {
        throw const UnexpectedException('Empty profile response');
      }
      return UserProfile.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<UserProfile> updateMine(ProfileUpdate update) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/me/profile',
        data: update.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const UnexpectedException('Empty profile update response');
      }
      return UserProfile.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});
