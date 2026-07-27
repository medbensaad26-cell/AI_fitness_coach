import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_fitness_coach_mobile/app/theme.dart';
import 'package:ai_fitness_coach_mobile/core/network/api_client.dart';
import 'package:ai_fitness_coach_mobile/core/storage/memory_secure_storage_service.dart';
import 'package:ai_fitness_coach_mobile/core/storage/secure_storage_service.dart';
import 'package:ai_fitness_coach_mobile/features/home/presentation/home_screen.dart';
import 'package:ai_fitness_coach_mobile/features/programs/data/program_models.dart';
import 'package:ai_fitness_coach_mobile/features/programs/data/programs_repository.dart';

class _FakeProgramsRepository extends ProgramsRepository {
  _FakeProgramsRepository(this._programs)
    : super(
        ApiClient(secureStorage: MemorySecureStorageService()),
      );

  final List<Program> _programs;

  @override
  Future<List<Program>> listMine() async => _programs;

  @override
  Future<Program> generate({DateTime? startDate}) async {
    throw UnimplementedError();
  }

  @override
  Future<Program> getById(String programId) async {
    return _programs.firstWhere((program) => program.id == programId);
  }
}

void main() {
  testWidgets('Empty home shows generate CTA', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(
            MemorySecureStorageService(initialToken: 'token'),
          ),
          programsRepositoryProvider.overrideWithValue(
            _FakeProgramsRepository(const []),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No programs yet.'), findsOneWidget);
    expect(find.text('Generate program'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('Home lists programs from repository', (WidgetTester tester) async {
    final program = Program(
      id: 'p1',
      userId: 'u1',
      name: 'Strength Session',
      goal: 'strength',
      startDate: DateTime(2026, 7, 23),
      status: 'active',
      exercises: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageServiceProvider.overrideWithValue(
            MemorySecureStorageService(initialToken: 'token'),
          ),
          programsRepositoryProvider.overrideWithValue(
            _FakeProgramsRepository([program]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Strength Session'), findsOneWidget);
    expect(find.text('Generate program'), findsNothing);
    expect(find.byTooltip('Generate program'), findsOneWidget);
  });
}
