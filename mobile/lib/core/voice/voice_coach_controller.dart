import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech / TTS status for coach voice UI.
@immutable
class VoiceCoachState {
  const VoiceCoachState({
    this.ready = false,
    this.speechAvailable = false,
    this.ttsAvailable = false,
    this.listening = false,
    this.speaking = false,
    this.autoSpeak = true,
    this.partialText = '',
    this.errorMessage,
  });

  final bool ready;
  final bool speechAvailable;
  final bool ttsAvailable;
  final bool listening;
  final bool speaking;
  final bool autoSpeak;
  final String partialText;
  final String? errorMessage;

  VoiceCoachState copyWith({
    bool? ready,
    bool? speechAvailable,
    bool? ttsAvailable,
    bool? listening,
    bool? speaking,
    bool? autoSpeak,
    String? partialText,
    String? errorMessage,
    bool clearError = false,
    bool clearPartial = false,
  }) {
    return VoiceCoachState(
      ready: ready ?? this.ready,
      speechAvailable: speechAvailable ?? this.speechAvailable,
      ttsAvailable: ttsAvailable ?? this.ttsAvailable,
      listening: listening ?? this.listening,
      speaking: speaking ?? this.speaking,
      autoSpeak: autoSpeak ?? this.autoSpeak,
      partialText: clearPartial ? '' : (partialText ?? this.partialText),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Device speech recognition + coach reply TTS.
class VoiceCoachController extends Notifier<VoiceCoachState> {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _initStarted = false;
  void Function(String text)? _onFinalResult;

  @override
  VoiceCoachState build() {
    ref.onDispose(() {
      _speech.cancel();
      _tts.stop();
    });
    // Lazy-init on first mic/speak use so widget tests don't hang on platform channels.
    return const VoiceCoachState();
  }

  Future<void> _ensureInitialized() async {
    if (_initStarted) return;
    _initStarted = true;

    var speechOk = false;
    var ttsOk = false;
    String? error;

    try {
      speechOk = await _speech.initialize(
        onError: (error) {
          state = state.copyWith(
            listening: false,
            errorMessage: error.errorMsg,
          );
        },
        onStatus: (status) {
          final listening = status == 'listening';
          if (!listening && state.listening) {
            state = state.copyWith(listening: false);
          }
        },
      );
    } catch (e) {
      error = 'Speech recognition unavailable on this device';
    }

    try {
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() {
        state = state.copyWith(speaking: false);
      });
      _tts.setCancelHandler(() {
        state = state.copyWith(speaking: false);
      });
      _tts.setErrorHandler((message) {
        state = state.copyWith(
          speaking: false,
          errorMessage: message.toString(),
        );
      });
      ttsOk = true;
    } catch (_) {
      error ??= 'Text-to-speech unavailable on this device';
    }

    state = state.copyWith(
      ready: true,
      speechAvailable: speechOk,
      ttsAvailable: ttsOk,
      errorMessage: speechOk || ttsOk ? null : error,
      clearError: speechOk || ttsOk,
    );
  }

  void toggleAutoSpeak() {
    final next = !state.autoSpeak;
    state = state.copyWith(autoSpeak: next);
    if (!next) {
      stopSpeaking();
    }
  }

  Future<void> startListening({
    required void Function(String text) onFinalResult,
    void Function(String text)? onPartial,
  }) async {
    await _ensureInitialized();
    if (!state.speechAvailable) {
      state = state.copyWith(
        errorMessage: 'Microphone / speech is not available here',
      );
      return;
    }
    if (state.listening) {
      await stopListening();
      return;
    }

    await stopSpeaking();
    _onFinalResult = onFinalResult;
    state = state.copyWith(
      listening: true,
      clearError: true,
      clearPartial: true,
    );

    await _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords;
        if (result.finalResult) {
          state = state.copyWith(
            listening: false,
            partialText: text,
          );
          final callback = _onFinalResult;
          _onFinalResult = null;
          if (text.trim().isNotEmpty) {
            callback?.call(text.trim());
          }
        } else {
          state = state.copyWith(partialText: text);
          onPartial?.call(text);
        }
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );
  }

  Future<void> stopListening() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {
      // Platform channel may be unavailable in tests / desktop.
    }
    state = state.copyWith(listening: false);
    _onFinalResult = null;
  }

  Future<void> speak(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;
    await _ensureInitialized();
    if (!state.ttsAvailable || !state.autoSpeak) return;

    await stopListening();
    state = state.copyWith(speaking: true, clearError: true);
    try {
      await _tts.stop();
      await _tts.speak(cleaned);
    } catch (_) {
      state = state.copyWith(speaking: false);
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Ignore platform TTS failures.
    }
    state = state.copyWith(speaking: false);
  }
}

final voiceCoachProvider =
    NotifierProvider<VoiceCoachController, VoiceCoachState>(
      VoiceCoachController.new,
    );
