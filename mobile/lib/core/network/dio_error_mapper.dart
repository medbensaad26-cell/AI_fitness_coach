import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../errors/app_exception.dart';

/// Maps [DioException] into the app's [AppException] hierarchy.
AppException mapDioException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.connectionError:
      return NetworkException(
        'Unable to reach the server at ${ApiConfig.baseUrl}. '
        'Check that the API is running.',
        cause: error,
      );
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return NetworkException(
        'The server took too long to respond. '
        'AI actions (generate / coach) can take a couple of minutes the first time.',
        cause: error,
      );
    case DioExceptionType.badResponse:
      return AppException(_messageFromResponse(error), cause: error);
    case DioExceptionType.cancel:
      return const AppException('Request was cancelled');
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return UnexpectedException(
        'Something went wrong talking to ${ApiConfig.baseUrl}. Please try again.',
        cause: error,
      );
  }
}

String _messageFromResponse(DioException error) {
  final status = error.response?.statusCode;
  final data = error.response?.data;

  final detail = _extractDetail(data);
  if (detail != null && detail.isNotEmpty) {
    return detail;
  }

  return switch (status) {
    400 => 'Invalid request',
    401 => 'Invalid email or password',
    404 => 'Not found',
    422 => 'Please check the form fields',
    500 => 'Server error. Please try again later.',
    _ => 'Request failed${status != null ? ' ($status)' : ''}',
  };
}

String? _extractDetail(dynamic data) {
  if (data is Map) {
    final detail = data['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] is String) {
        return first['msg'] as String;
      }
      return first.toString();
    }
  }
  if (data is String && data.isNotEmpty) return data;
  return null;
}
