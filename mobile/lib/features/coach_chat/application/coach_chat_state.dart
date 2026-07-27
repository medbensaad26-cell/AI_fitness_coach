/// One turn in the floating coach chat (not tied to a workout session).
class CoachChatMessage {
  const CoachChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    this.safetyFlag = false,
    this.suggestedAction,
    required this.at,
  });

  final String id;
  final bool isUser;
  final String text;
  final bool safetyFlag;
  final String? suggestedAction;
  final DateTime at;
}

/// UI + conversation state for the global coach chat overlay.
class CoachChatState {
  const CoachChatState({
    this.isOpen = false,
    this.isSending = false,
    this.messages = const [],
    this.errorMessage,
  });

  final bool isOpen;
  final bool isSending;
  final List<CoachChatMessage> messages;
  final String? errorMessage;

  CoachChatState copyWith({
    bool? isOpen,
    bool? isSending,
    List<CoachChatMessage>? messages,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CoachChatState(
      isOpen: isOpen ?? this.isOpen,
      isSending: isSending ?? this.isSending,
      messages: messages ?? this.messages,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
