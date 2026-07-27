import 'package:flutter_test/flutter_test.dart';
import 'package:ai_fitness_coach_mobile/core/network/api_client.dart';
import 'package:ai_fitness_coach_mobile/core/storage/memory_secure_storage_service.dart';

void main() {
  test('ApiClient initializes with custom dio and secure storage', () async {
    final fakeStorage = MemorySecureStorageService(initialToken: 'fake_jwt_123');
    final client = ApiClient(secureStorage: fakeStorage);

    expect(client.dio, isNotNull);
    expect(client.dio.options.baseUrl, isNotEmpty);
    expect(client.secureStorage, equals(fakeStorage));
  });
}
