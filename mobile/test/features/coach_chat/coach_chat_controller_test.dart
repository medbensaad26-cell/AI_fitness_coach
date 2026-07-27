import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_fitness_coach_mobile/core/network/api_client.dart';
import 'package:ai_fitness_coach_mobile/core/storage/memory_secure_storage_service.dart';
import 'package:ai_fitness_coach_mobile/features/coach_chat/application/coach_chat_controller.dart';
import 'package:ai_fitness_coach_mobile/features/sessions/data/session_models.dart';
import 'package:ai_fitness_coach_mobile/features/sessions/data/sessions_repository.dart';

class _FakeCoachRepository extends CoachRepository {
  _FakeCoachRepository()
    : super(ApiClient(secureStorage: MemorySecureStorageService()));

  String? lastUserMessage;

  @override
  Future<CoachMidSessionResult> midSession({
    required String userMessage,
    int? readiness,
    List<SessionExerciseFeedback> recentFeedback = const [],
    Map<String, dynamic>? currentExercise,
  }) async {
    lastUserMessage = userMessage;
    expect(currentExercise, isNull);
    expect(recentFeedback, isEmpty);
    return const CoachMidSessionResult(
      message: 'Take an easier variation and keep depth comfortable.',
      suggestedAction: 'regress_exercise',
      safetyFlag: true,
    );
  }
}

void main() {
  test('CoachChatController sends question without session context', () async {
    final fakeCoach = _FakeCoachRepository();
    final container = ProviderContainer(
      overrides: [
        coachRepositoryProvider.overrideWithValue(fakeCoach),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(coachChatProvider.notifier);
    notifier.open();
    await notifier.send('Should I skip squats?');

    final state = container.read(coachChatProvider);
    expect(fakeCoach.lastUserMessage, 'Should I skip squats?');
    expect(state.isSending, isFalse);
    expect(state.messages, hasLength(2));
    expect(state.messages.first.isUser, isTrue);
    expect(state.messages.last.isUser, isFalse);
    expect(state.messages.last.text, contains('easier variation'));
    expect(state.messages.last.suggestedAction, 'regress_exercise');
    expect(state.messages.last.safetyFlag, isTrue);
  });

  test('CoachChatController ignores blank messages', () async {
    final fakeCoach = _FakeCoachRepository();
    final container = ProviderContainer(
      overrides: [
        coachRepositoryProvider.overrideWithValue(fakeCoach),
      ],
    );
    addTearDown(container.dispose);

    await container.read(coachChatProvider.notifier).send('   ');
    expect(fakeCoach.lastUserMessage, isNull);
    expect(container.read(coachChatProvider).messages, isEmpty);
  });
}
