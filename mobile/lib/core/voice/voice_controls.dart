import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import 'voice_coach_controller.dart';

/// Mic button that fills [controller] with recognized speech.
class VoiceMicButton extends ConsumerWidget {
  const VoiceMicButton({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onFinalResult,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onFinalResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceCoachProvider);
    final listening = voice.listening;
    // Before first init, still show an enabled mic so users can trigger permission flow.
    final canListen = enabled && (voice.speechAvailable || !voice.ready);

    return IconButton(
      onPressed: !enabled
          ? null
          : () async {
              if (listening) {
                await ref.read(voiceCoachProvider.notifier).stopListening();
                return;
              }
              if (!canListen) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      voice.errorMessage ??
                          'Voice input is not available on this device',
                    ),
                  ),
                );
                return;
              }
              await ref.read(voiceCoachProvider.notifier).startListening(
                    onPartial: (text) {
                      controller.text = text;
                      controller.selection = TextSelection.collapsed(
                        offset: controller.text.length,
                      );
                    },
                    onFinalResult: (text) {
                      controller.text = text;
                      controller.selection = TextSelection.collapsed(
                        offset: text.length,
                      );
                      onFinalResult?.call(text);
                    },
                  );
            },
      icon: Icon(
        listening ? Icons.mic_rounded : Icons.mic_none_rounded,
        color: listening
            ? Theme.of(context).colorScheme.error
            : (canListen ? AppTheme.pineDeep : AppTheme.stone),
      ),
      style: IconButton.styleFrom(
        backgroundColor: listening
            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.12)
            : AppTheme.mist,
      ),
    );
  }
}

/// Toggle whether coach replies are spoken aloud.
class VoiceAutoSpeakToggle extends ConsumerWidget {
  const VoiceAutoSpeakToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceCoachProvider);

    return IconButton(
      onPressed: voice.ttsAvailable
          ? () => ref.read(voiceCoachProvider.notifier).toggleAutoSpeak()
          : null,
      icon: Icon(
        voice.autoSpeak ? Icons.volume_up_rounded : Icons.volume_off_rounded,
        color: voice.autoSpeak && voice.ttsAvailable
            ? AppTheme.pineDeep
            : AppTheme.stone,
      ),
    );
  }
}

/// Small status line while listening / speaking.
class VoiceStatusLabel extends ConsumerWidget {
  const VoiceStatusLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceCoachProvider);
    final theme = Theme.of(context);

    String? label;
    if (voice.listening) {
      label = voice.partialText.isEmpty
          ? 'Listening…'
          : 'Hearing: ${voice.partialText}';
    } else if (voice.speaking) {
      label = 'Coach is speaking…';
    }

    if (label == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.stone),
      ),
    );
  }
}
