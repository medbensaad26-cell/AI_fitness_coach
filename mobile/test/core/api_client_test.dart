import 'package:flutter_test/flutter_test.dart';
import 'package:ai_fitness_coach_mobile/core/network/api_client.dart';
import 'package:ai_fitness_coach_mobile/core/storage/secure_storage_service.dart';

class FakeSecureStorageService extends SecureStorageService {
  FakeSecureStorageService({this.token});

  final String? token;

  @override
  Future<String?> readAccessToken() async => token;
}

void main() {
  test('ApiClient initializes with custom dio and secure storage', () async {
    final fakeStorage = FakeSecureStorageService(token: 'fake_jwt_123');
    final client = ApiClient(secureStorage: fakeStorage);

    expect(client.dio, isNotNull);
    expect(client.dio.options.baseUrl, isNotEmpty);
    expect(client.secureStorage, equals(fakeStorage));
  });
}
