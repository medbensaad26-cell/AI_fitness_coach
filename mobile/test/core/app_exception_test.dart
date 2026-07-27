import 'package:flutter_test/flutter_test.dart';
import 'package:ai_fitness_coach_mobile/core/errors/app_exception.dart';

void main() {
  group('AppException hierarchy tests', () {
    test('AppException toString displays formatted message', () {
      const exception = AppException('Something failed');
      expect(exception.toString(), equals('AppException: Something failed'));
      expect(exception.message, equals('Something failed'));
      expect(exception.cause, isNull);
    });

    test('NetworkException inherits from AppException', () {
      const exception = NetworkException('Connection timeout');
      expect(exception, isA<AppException>());
      expect(exception.message, equals('Connection timeout'));
    });

    test('UnexpectedException inherits from AppException', () {
      const exception = UnexpectedException('Unknown server error');
      expect(exception, isA<AppException>());
      expect(exception.message, equals('Unknown server error'));
    });
  });
}
