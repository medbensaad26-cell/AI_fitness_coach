import 'package:flutter_test/flutter_test.dart';

import 'package:ai_fitness_coach_mobile/core/voice/voice_coach_controller.dart';

void main() {
  test('VoiceCoachState copyWith updates listening and clears partial', () {
    const initial = VoiceCoachState(
      ready: true,
      speechAvailable: true,
      listening: true,
      partialText: 'hello',
      errorMessage: 'oops',
    );

    final next = initial.copyWith(
      listening: false,
      clearPartial: true,
      clearError: true,
      autoSpeak: false,
    );

    expect(next.ready, isTrue);
    expect(next.speechAvailable, isTrue);
    expect(next.listening, isFalse);
    expect(next.partialText, isEmpty);
    expect(next.errorMessage, isNull);
    expect(next.autoSpeak, isFalse);
  });
}
