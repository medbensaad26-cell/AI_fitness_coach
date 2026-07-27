import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_fitness_coach_mobile/app/app.dart';
import 'package:ai_fitness_coach_mobile/core/storage/memory_secure_storage_service.dart';
import 'package:ai_fitness_coach_mobile/core/storage/secure_storage_service.dart';

void main() {
  testWidgets('App bootstraps to login when no token', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(
            MemorySecureStorageService(),
          ),
        ],
        child: const AiFitnessCoachApp(),
      ),
    );

    // Splash while auth bootstraps
    expect(find.text('AI Fitness Coach'), findsWidgets);
    await tester.pumpAndSettle();

    // Redirected to login
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
