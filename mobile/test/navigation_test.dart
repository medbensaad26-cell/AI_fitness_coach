import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_fitness_coach_mobile/app/app.dart';
import 'package:ai_fitness_coach_mobile/core/network/api_client.dart';
import 'package:ai_fitness_coach_mobile/core/storage/memory_secure_storage_service.dart';
import 'package:ai_fitness_coach_mobile/core/storage/secure_storage_service.dart';
import 'package:ai_fitness_coach_mobile/features/auth/application/auth_controller.dart';
import 'package:ai_fitness_coach_mobile/features/programs/data/program_models.dart';
import 'package:ai_fitness_coach_mobile/features/programs/data/programs_repository.dart';

class _EmptyProgramsRepository extends ProgramsRepository {
  _EmptyProgramsRepository()
    : super(ApiClient(secureStorage: MemorySecureStorageService()));

  @override
  Future<List<Program>> listMine() async => const [];

  @override
  Future<Program> generate({DateTime? startDate}) async {
    throw UnimplementedError();
  }

  @override
  Future<Program> getById(String programId) async {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('Unauthenticated user can open register and return to login',
      (WidgetTester tester) async {
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
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_rounded), findsNothing);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.byTooltip('Back to login'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to login'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('Authenticated session opens home', (WidgetTester tester) async {
    final storage = MemorySecureStorageService(initialToken: 'test_jwt');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(storage),
          programsRepositoryProvider.overrideWithValue(
            _EmptyProgramsRepository(),
          ),
        ],
        child: const AiFitnessCoachApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('No programs yet.'), findsOneWidget);
    expect(find.text('Generate program'), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.smart_toy_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Coach chat'), findsOneWidget);
    expect(find.text('Ask anytime — no workout required'), findsOneWidget);

    // Close chat so home controls are tappable again.
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Coach chat'), findsNothing);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    final auth = ProviderScope.containerOf(
      tester.element(find.text('Sign in')),
    ).read(authControllerProvider);
    expect(auth.isAuthenticated, isFalse);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_rounded), findsNothing);
  });
}
