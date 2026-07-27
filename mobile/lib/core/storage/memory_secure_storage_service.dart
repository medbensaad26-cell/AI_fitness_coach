import '../storage/secure_storage_service.dart';

/// In-memory token store for widget/unit tests.
class MemorySecureStorageService extends SecureStorageService {
  MemorySecureStorageService({String? initialToken}) : _token = initialToken;

  String? _token;

  @override
  Future<void> writeAccessToken(String token) async {
    _token = token;
  }

  @override
  Future<String?> readAccessToken() async => _token;

  @override
  Future<void> deleteAccessToken() async {
    _token = null;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}
