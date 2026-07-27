import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/voice/voice_coach_controller.dart';
import '../../../core/voice/voice_controls.dart';
import '../application/coach_chat_controller.dart';
import '../application/coach_chat_state.dart';

/// Floating coach button + expandable chat panel for authenticated screens.
class CoachChatOverlay extends ConsumerStatefulWidget {
  const CoachChatOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CoachChatOverlay> createState() => _CoachChatOverlayState();
}

class _CoachChatOverlayState extends ConsumerState<CoachChatOverlay> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputController.text;
    _inputController.clear();
    await ref.read(coachChatProvider.notifier).send(text);
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(coachChatProvider);

    ref.listen<CoachChatState>(coachChatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToEnd();
        final last = next.messages.isEmpty ? null : next.messages.last;
        if (last != null && !last.isUser) {
          ref.read(voiceCoachProvider.notifier).speak(last.text);
        }
      }
    });

    return Stack(
      children: [
        widget.child,
        if (chat.isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => ref.read(coachChatProvider.notifier).close(),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.28),
              ),
            ),
          ),
        if (chat.isOpen)
          Positioned(
            right: 16,
            bottom: 88,
            left: 16,
            child: Align(
              alignment: Alignment.bottomRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
                child: _CoachChatPanel(
                  chat: chat,
                  inputController: _inputController,
                  scrollController: _scrollController,
                  onSend: chat.isSending ? null : _send,
                  onClose: () {
                    ref.read(coachChatProvider.notifier).close();
                    ref.read(voiceCoachProvider.notifier).stopListening();
                    ref.read(voiceCoachProvider.notifier).stopSpeaking();
                  },
                  onClear: () =>
                      ref.read(coachChatProvider.notifier).clearConversation(),
                ),
              ),
            ),
          ),
        Positioned(
          right: 20,
          bottom: 24,
          child: _CoachFab(
            isOpen: chat.isOpen,
            isSending: chat.isSending,
            onPressed: () => ref.read(coachChatProvider.notifier).toggle(),
          ),
        ),
      ],
    );
  }
}

class _CoachFab extends StatelessWidget {
  const _CoachFab({
    required this.isOpen,
    required this.isSending,
    required this.onPressed,
  });

  final bool isOpen;
  final bool isSending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isOpen ? 'Close coach chat' : 'Ask the coach',
      child: Material(
        color: AppTheme.pine,
        elevation: 4,
        shadowColor: AppTheme.pineDeep.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 58,
            height: 58,
            child: isSending && !isOpen
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isOpen ? Icons.close_rounded : Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
          ),
        ),
      ),
    );
  }
}

class _CoachChatPanel extends StatelessWidget {
  const _CoachChatPanel({
    required this.chat,
    required this.inputController,
    required this.scrollController,
    required this.onSend,
    required this.onClose,
    required this.onClear,
  });

  final CoachChatState chat;
  final TextEditingController inputController;
  final ScrollController scrollController;
  final VoidCallback? onSend;
  final VoidCallback onClose;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white.withValues(alpha: 0.97),
      elevation: 8,
      shadowColor: AppTheme.pineDeep.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.mistDeep.withValues(alpha: 0.95)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.pine.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: AppTheme.pineDeep,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coach chat',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Ask anytime — no workout required',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.stone,
                        ),
                      ),
                    ],
                  ),
                ),
                if (chat.messages.isNotEmpty)
                  IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                const VoiceAutoSpeakToggle(),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: chat.messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Ask about form, recovery, substitutions, or how to progress. Tap the mic to speak.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.stone,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) {
                      return _ChatBubble(message: chat.messages[index]);
                    },
                  ),
          ),
          if (chat.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                chat.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (chat.isSending)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('Coach is thinking…'),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: VoiceStatusLabel(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                VoiceMicButton(
                  controller: inputController,
                  enabled: !chat.isSending,
                  onFinalResult: (_) {
                    if (onSend != null) onSend!();
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: inputController,
                    enabled: !chat.isSending,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (onSend != null) onSend!();
                    },
                    decoration: const InputDecoration(
                      hintText: 'Ask or tap the mic…',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: onSend,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.pine,
                    foregroundColor: Colors.white,
                  ),
                  icon: chat.isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final CoachChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final align =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isUser
        ? AppTheme.pine
        : (message.safetyFlag
            ? theme.colorScheme.errorContainer
            : AppTheme.mist);
    final textColor = isUser
        ? Colors.white
        : (message.safetyFlag
            ? theme.colorScheme.onErrorContainer
            : AppTheme.ink);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Text(
                message.safetyFlag ? 'Coach · safety' : 'Coach',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: message.safetyFlag
                      ? theme.colorScheme.error
                      : AppTheme.pineDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                      ),
                    ),
                    if (!isUser &&
                        message.suggestedAction != null &&
                        message.suggestedAction!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Suggested: ${message.suggestedAction!.replaceAll('_', ' ')}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: textColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
