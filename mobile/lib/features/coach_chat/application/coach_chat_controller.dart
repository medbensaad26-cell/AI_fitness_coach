import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../sessions/data/sessions_repository.dart';
import 'coach_chat_state.dart';

/// Global free-form coach Q&A (uses mid-session API without workout context).
class CoachChatController extends Notifier<CoachChatState> {
  @override
  CoachChatState build() => const CoachChatState();

  void open() {
    state = state.copyWith(isOpen: true, clearError: true);
  }

  void close() {
    state = state.copyWith(isOpen: false, clearError: true);
  }

  void toggle() {
    state = state.copyWith(isOpen: !state.isOpen, clearError: true);
  }

  void clearConversation() {
    state = state.copyWith(messages: const [], clearError: true);
  }

  Future<void> send(String rawMessage) async {
    final text = rawMessage.trim();
    if (text.isEmpty || state.isSending) return;

    final now = DateTime.now();
    final userMessage = CoachChatMessage(
      id: 'u-${now.microsecondsSinceEpoch}',
      isUser: true,
      text: text,
      at: now,
    );

    state = state.copyWith(
      isSending: true,
      clearError: true,
      messages: [...state.messages, userMessage],
    );

    try {
      final result = await ref.read(coachRepositoryProvider).midSession(
            userMessage: text,
          );
      final replyAt = DateTime.now();
      final replyText = result.message.trim().isEmpty
          ? 'I got a blank reply — try asking again in a moment.'
          : result.message;
      final coachMessage = CoachChatMessage(
        id: 'c-${replyAt.microsecondsSinceEpoch}',
        isUser: false,
        text: replyText,
        safetyFlag: result.safetyFlag,
        suggestedAction: result.suggestedAction,
        at: replyAt,
      );
      state = state.copyWith(
        isSending: false,
        messages: [...state.messages, coachMessage],
      );
    } on AppException catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: error.message,
      );
    } catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Failed to reach the coach',
      );
    }
  }
}

final coachChatProvider =
    NotifierProvider<CoachChatController, CoachChatState>(
      CoachChatController.new,
    );
