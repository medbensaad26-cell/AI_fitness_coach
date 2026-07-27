import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_fitness_coach_mobile/core/storage/memory_secure_storage_service.dart';
import 'package:ai_fitness_coach_mobile/core/storage/secure_storage_service.dart';
import 'package:ai_fitness_coach_mobile/features/auth/application/auth_controller.dart';

void main() {
  test('AuthController restores authenticated session from storage', () async {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(
          MemorySecureStorageService(initialToken: 'persisted-jwt'),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Trigger build + bootstrap microtask
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(authControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.isAuthenticated, isTrue);
  });

  test('AuthController logout clears token', () async {
    final storage = MemorySecureStorageService(initialToken: 'persisted-jwt');
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    await container.read(authControllerProvider.notifier).logout();

    expect(container.read(authControllerProvider).isAuthenticated, isFalse);
    expect(await storage.readAccessToken(), isNull);
  });
}
