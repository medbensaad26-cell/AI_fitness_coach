import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/voice/voice_coach_controller.dart';
import '../../../core/voice/voice_controls.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../programs/application/programs_controller.dart';
import '../../programs/presentation/suggest_next_dialog.dart';
import '../application/active_session_controller.dart';
import '../data/session_models.dart';

/// Live workout: coach check-in → exercises → wrap-up → save session.
class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key, required this.programId});

  final String programId;

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  final _askController = TextEditingController();
  bool _asking = false;

  @override
  void dispose() {
    _askController.dispose();
    super.dispose();
  }

  Future<void> _askCoach() async {
    final message = _askController.text.trim();
    if (message.isEmpty || _asking) return;
    setState(() => _asking = true);
    try {
      final result = await ref
          .read(activeSessionProvider(widget.programId).notifier)
          .askCoach(message);
      if (!mounted) return;
      _askController.clear();
      await ref.read(voiceCoachProvider.notifier).speak(result.message);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(result.safetyFlag ? 'Coach (safety)' : 'Coach'),
          content: Text(
            '${result.message}\n\nSuggested: ${result.suggestedAction}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(voiceCoachProvider.notifier).stopSpeaking();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeSessionProvider(widget.programId));
    final notifier =
        ref.read(activeSessionProvider(widget.programId).notifier);

    return Scaffold(
      body: AppBackground(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.close),
                      onPressed: () => context.go(AppRoutes.home),
                    ),
                    Expanded(
                      child: Text(
                        state.program?.name ?? 'Active workout',
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: switch (state.phase) {
          ActiveSessionPhase.loading => const LoadingView(
              message: 'Starting coach check-in…',
            ),
          ActiveSessionPhase.error => ErrorView(
              message: state.errorMessage ?? 'Something went wrong',
              onRetry: notifier.retry,
            ),
          ActiveSessionPhase.checkIn => _CheckInPhase(
              state: state,
              onContinue: ({int? readiness, String? painNote}) {
                notifier.completeCheckIn(
                  readiness: readiness,
                  painNote: painNote,
                );
              },
            ),
          ActiveSessionPhase.exercising => _ExercisingPhase(
              key: ValueKey('ex-${state.exerciseIndex}'),
              state: state,
              asking: _asking,
              askController: _askController,
              onAskCoach: _askCoach,
              onLog: ({
                required int setsCompleted,
                String? repsCompleted,
                double? weightKg,
                int? difficulty,
                bool skipped = false,
                String? notes,
              }) async {
                try {
                  await notifier.logCurrentExercise(
                    setsCompleted: setsCompleted,
                    repsCompleted: repsCompleted,
                    weightKg: weightKg,
                    difficulty: difficulty,
                    skipped: skipped,
                    notes: notes,
                  );
                } on AppException catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.message)),
                  );
                }
              },
              onFinishEarly: notifier.finishEarly,
            ),
          ActiveSessionPhase.wrappingUp => _WrapUpPhase(
              state: state,
              onSave: ({
                required int overallFeeling,
                required int fatigueLevel,
                String? comments,
              }) async {
                try {
                  await notifier.wrapUpAndSave(
                    overallFeeling: overallFeeling,
                    fatigueLevel: fatigueLevel,
                    comments: comments,
                  );
                } on AppException catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.message)),
                  );
                }
              },
            ),
          ActiveSessionPhase.done => _DonePhase(
              state: state,
              onHistory: () => context.go(AppRoutes.sessionHistory),
              onHome: () => context.go(AppRoutes.home),
              onSuggestNext: () async {
                try {
                  final result = await ref
                      .read(programsListProvider.notifier)
                      .suggestNext();
                  if (!context.mounted) return;
                  await showSuggestNextResultDialog(
                    context,
                    result: result,
                  );
                } on AppException catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.message)),
                  );
                }
              },
            ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckInPhase extends StatefulWidget {
  const _CheckInPhase({required this.state, required this.onContinue});

  final ActiveSessionState state;
  final void Function({int? readiness, String? painNote}) onContinue;

  @override
  State<_CheckInPhase> createState() => _CheckInPhaseState();
}

class _CheckInPhaseState extends State<_CheckInPhase> {
  int _readiness = 3;
  final _painController = TextEditingController(text: 'none');

  @override
  void dispose() {
    _painController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prompts = widget.state.startResult?.prompts ?? const <CoachPrompt>[];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Coach check-in',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.state.coachMessage ?? '',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        ...prompts.map((prompt) {
          if (prompt.inputType == 'scale') {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prompt.label, style: theme.textTheme.titleSmall),
                Slider(
                  value: _readiness.toDouble(),
                  min: (prompt.scaleMin ?? 1).toDouble(),
                  max: (prompt.scaleMax ?? 5).toDouble(),
                  divisions: ((prompt.scaleMax ?? 5) - (prompt.scaleMin ?? 1)),
                  label: '$_readiness',
                  onChanged: (value) =>
                      setState(() => _readiness = value.round()),
                ),
                const SizedBox(height: 12),
              ],
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _painController,
              decoration: InputDecoration(labelText: prompt.label),
            ),
          );
        }),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => widget.onContinue(
            readiness: _readiness,
            painNote: _painController.text.trim(),
          ),
          child: const Text('Start exercises'),
        ),
      ],
    );
  }
}

class _ExercisingPhase extends ConsumerStatefulWidget {
  const _ExercisingPhase({
    super.key,
    required this.state,
    required this.asking,
    required this.askController,
    required this.onAskCoach,
    required this.onLog,
    required this.onFinishEarly,
  });

  final ActiveSessionState state;
  final bool asking;
  final TextEditingController askController;
  final VoidCallback onAskCoach;
  final Future<void> Function({
    required int setsCompleted,
    String? repsCompleted,
    double? weightKg,
    int? difficulty,
    bool skipped,
    String? notes,
  }) onLog;
  final VoidCallback onFinishEarly;

  @override
  ConsumerState<_ExercisingPhase> createState() => _ExercisingPhaseState();
}

class _ExercisingPhaseState extends ConsumerState<_ExercisingPhase> {
  late final TextEditingController _setsController;
  late final TextEditingController _repsController;
  late final TextEditingController _weightController;
  late final TextEditingController _notesController;
  int _difficulty = 3;
  bool _skipped = false;

  @override
  void initState() {
    super.initState();
    final exercise = widget.state.currentExercise;
    _setsController = TextEditingController(
      text: (exercise?.sets ?? 0).toString(),
    );
    _repsController = TextEditingController(text: exercise?.reps ?? '');
    _weightController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercise = widget.state.currentExercise;
    final total = widget.state.program?.exercises.length ?? 0;
    final index = widget.state.exerciseIndex;

    if (exercise == null) {
      return const Center(child: Text('No exercises in this program.'));
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Exercise ${index + 1} of $total',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          exercise.exerciseName,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Plan: ${exercise.sets} × ${exercise.reps}'
          '${exercise.notes != null && exercise.notes!.isNotEmpty ? ' · ${exercise.notes}' : ''}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (widget.state.coachMessage != null) ...[
          const SizedBox(height: 16),
          AppSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.state.safetyFlag ? 'Coach · safety' : 'Coach',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: widget.state.safetyFlag
                        ? theme.colorScheme.error
                        : AppTheme.pineDeep,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.state.coachMessage!,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: _setsController,
          keyboardType: TextInputType.number,
          enabled: !widget.state.busy,
          decoration: const InputDecoration(labelText: 'Sets completed'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _repsController,
          enabled: !widget.state.busy,
          decoration: const InputDecoration(labelText: 'Reps completed'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          enabled: !widget.state.busy,
          decoration: const InputDecoration(labelText: 'Weight (kg)'),
        ),
        const SizedBox(height: 12),
        Text('Difficulty: $_difficulty', style: theme.textTheme.titleSmall),
        Slider(
          value: _difficulty.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '$_difficulty',
          onChanged: widget.state.busy
              ? null
              : (value) => setState(() => _difficulty = value.round()),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Skipped'),
          value: _skipped,
          onChanged: widget.state.busy
              ? null
              : (value) => setState(() => _skipped = value),
        ),
        TextField(
          controller: _notesController,
          enabled: !widget.state.busy,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: widget.state.busy
              ? null
              : () async {
                  final sets = int.tryParse(_setsController.text.trim()) ?? 0;
                  final weightText = _weightController.text.trim();
                  await widget.onLog(
                    setsCompleted: sets,
                    repsCompleted: _repsController.text.trim().isEmpty
                        ? null
                        : _repsController.text.trim(),
                    weightKg: weightText.isEmpty
                        ? null
                        : double.tryParse(weightText),
                    difficulty: _difficulty,
                    skipped: _skipped,
                    notes: _notesController.text.trim().isEmpty
                        ? null
                        : _notesController.text.trim(),
                  );
                },
          child: widget.state.busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.state.hasMoreExercises
                      ? 'Log & next exercise'
                      : 'Log & finish',
                ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: widget.state.busy ? null : widget.onFinishEarly,
          child: const Text('Finish session early'),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text('Ask the coach', style: theme.textTheme.titleSmall),
            ),
            const VoiceAutoSpeakToggle(),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VoiceMicButton(
              controller: widget.askController,
              enabled: !widget.asking && !widget.state.busy,
              onFinalResult: (_) => widget.onAskCoach(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.askController,
                enabled: !widget.asking && !widget.state.busy,
                decoration: const InputDecoration(
                  hintText: 'e.g. Should I rest? (or use mic)',
                ),
              ),
            ),
          ],
        ),
        const VoiceStatusLabel(),
        const SizedBox(height: 8),
        TextButton(
          onPressed:
              widget.asking || widget.state.busy ? null : widget.onAskCoach,
          child: widget.asking
              ? const Text('Asking…')
              : const Text('Send to coach'),
        ),
        if (widget.state.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.state.errorMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _WrapUpPhase extends StatefulWidget {
  const _WrapUpPhase({required this.state, required this.onSave});

  final ActiveSessionState state;
  final Future<void> Function({
    required int overallFeeling,
    required int fatigueLevel,
    String? comments,
  }) onSave;

  @override
  State<_WrapUpPhase> createState() => _WrapUpPhaseState();
}

class _WrapUpPhaseState extends State<_WrapUpPhase> {
  int _feeling = 4;
  int _fatigue = 3;
  final _commentsController = TextEditingController();

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Wrap up',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Logged ${widget.state.feedback.length} exercise(s). '
          'Rate how you feel, then save the session.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Text('Overall feeling: $_feeling', style: theme.textTheme.titleSmall),
        Slider(
          value: _feeling.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '$_feeling',
          onChanged: widget.state.busy
              ? null
              : (value) => setState(() => _feeling = value.round()),
        ),
        Text('Fatigue: $_fatigue', style: theme.textTheme.titleSmall),
        Slider(
          value: _fatigue.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '$_fatigue',
          onChanged: widget.state.busy
              ? null
              : (value) => setState(() => _fatigue = value.round()),
        ),
        TextField(
          controller: _commentsController,
          enabled: !widget.state.busy,
          decoration: const InputDecoration(labelText: 'Comments'),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: widget.state.busy
              ? null
              : () => widget.onSave(
                    overallFeeling: _feeling,
                    fatigueLevel: _fatigue,
                    comments: _commentsController.text.trim().isEmpty
                        ? null
                        : _commentsController.text.trim(),
                  ),
          child: widget.state.busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save session'),
        ),
        if (widget.state.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.state.errorMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _DonePhase extends StatefulWidget {
  const _DonePhase({
    required this.state,
    required this.onHistory,
    required this.onHome,
    required this.onSuggestNext,
  });

  final ActiveSessionState state;
  final VoidCallback onHistory;
  final VoidCallback onHome;
  final Future<void> Function() onSuggestNext;

  @override
  State<_DonePhase> createState() => _DonePhaseState();
}

class _DonePhaseState extends State<_DonePhase> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Session saved',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            state.coachMessage ?? 'Great work — session recorded.',
            style: theme.textTheme.bodyLarge,
          ),
          if (state.savedSession?.durationMinutes != null) ...[
            const SizedBox(height: 8),
            Text(
              'Duration: ${state.savedSession!.durationMinutes} min',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.stone,
              ),
            ),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await widget.onSuggestNext();
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.trending_up_rounded),
            label: Text(
              _busy ? 'Suggesting next…' : 'Suggest next program',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : widget.onHistory,
            child: const Text('View session history'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy ? null : widget.onHome,
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }
}
