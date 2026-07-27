import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../sessions/data/session_models.dart';
import '../../sessions/data/sessions_repository.dart';

/// One saved workout session with per-exercise results.
class SessionDetailsScreen extends ConsumerWidget {
  const SessionDetailsScreen({super.key, required this.sessionId});

  final String sessionId;

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessionAsync = ref.watch(sessionDetailsProvider(sessionId));

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back to history',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.go(AppRoutes.sessionHistory),
                    ),
                    Expanded(
                      child: Text(
                        'Session details',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: sessionAsync.when(
                  loading: () =>
                      const LoadingView(message: 'Loading session…'),
                  error: (error, _) => ErrorView(
                    message: error is AppException
                        ? error.message
                        : 'Failed to load session',
                    onRetry: () =>
                        ref.invalidate(sessionDetailsProvider(sessionId)),
                  ),
                  data: (session) => _SessionDetailsBody(
                    session: session,
                    startLabel: _formatDateTime(session.startTime),
                    endLabel: session.endTime != null
                        ? _formatDateTime(session.endTime!)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionDetailsBody extends StatelessWidget {
  const _SessionDetailsBody({
    required this.session,
    required this.startLabel,
    required this.endLabel,
  });

  final WorkoutSession session;
  final String startLabel;
  final String? endLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(startLabel, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (session.durationMinutes != null)
              AppChip(
                label: '${session.durationMinutes} min',
                emphasized: true,
              ),
            AppChip(label: '${session.exercises.length} exercises'),
            if (session.overallFeeling != null)
              AppChip(label: 'feeling ${session.overallFeeling}/5'),
            if (session.fatigueLevel != null)
              AppChip(label: 'fatigue ${session.fatigueLevel}/5'),
          ],
        ),
        if (endLabel != null) ...[
          const SizedBox(height: 12),
          Text(
            'Ended $endLabel',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.stone),
          ),
        ],
        if (session.comments != null && session.comments!.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Notes', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          AppSurface(
            child: Text(
              session.comments!,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
        const SizedBox(height: 28),
        Text('Exercises logged', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (session.exercises.isEmpty)
          Text(
            'No exercises were logged for this session.',
            style: theme.textTheme.bodyLarge?.copyWith(color: AppTheme.stone),
          )
        else
          ...session.exercises.map(
            (exercise) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LoggedExerciseTile(exercise: exercise),
            ),
          ),
        if (session.programId != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.go(
              AppRoutes.programDetailsPath(session.programId!),
            ),
            icon: const Icon(Icons.fitness_center_outlined),
            label: const Text('Open related program'),
          ),
        ],
      ],
    );
  }
}

class _LoggedExerciseTile extends StatelessWidget {
  const _LoggedExerciseTile({required this.exercise});

  final SessionExerciseFeedback exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = <String>[
      '${exercise.setsCompleted} sets',
      if (exercise.repsCompleted != null && exercise.repsCompleted!.isNotEmpty)
        '${exercise.repsCompleted} reps',
      if (exercise.weightKg != null) '${exercise.weightKg} kg',
      if (exercise.difficulty != null) 'difficulty ${exercise.difficulty}/5',
    ].join(' · ');

    return AppSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: exercise.skipped
                  ? AppTheme.stone.withValues(alpha: 0.12)
                  : AppTheme.pine.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              exercise.skipped
                  ? Icons.skip_next_rounded
                  : Icons.check_circle_outline_rounded,
              color: exercise.skipped ? AppTheme.stone : AppTheme.pineDeep,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.exerciseName,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (exercise.skipped)
                      const AppChip(label: 'skipped', emphasized: true)
                    else if (meta.isNotEmpty)
                      AppChip(label: meta),
                  ],
                ),
                if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    exercise.notes!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.stone,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final sessionDetailsProvider =
    FutureProvider.autoDispose.family<WorkoutSession, String>((ref, sessionId) {
  return ref.watch(sessionsRepositoryProvider).getById(sessionId);
});
