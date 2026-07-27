import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/programs_controller.dart';
import '../data/program_models.dart';

/// Shows one program and its ordered exercises from the API.
class ProgramDetailsScreen extends ConsumerWidget {
  const ProgramDetailsScreen({super.key, required this.programId});

  final String programId;

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final programAsync = ref.watch(programDetailsProvider(programId));

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
                      tooltip: 'Back to home',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.go(AppRoutes.home),
                    ),
                    Expanded(
                      child: Text(
                        'Program details',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: programAsync.when(
                  loading: () =>
                      const LoadingView(message: 'Loading program…'),
                  error: (error, _) => ErrorView(
                    message: error is AppException
                        ? error.message
                        : 'Failed to load program',
                    onRetry: () =>
                        ref.invalidate(programDetailsProvider(programId)),
                  ),
                  data: (program) => _ProgramDetailsBody(
                    program: program,
                    dateLabel: _formatDate(program.startDate),
                    endDateLabel: program.endDate != null
                        ? _formatDate(program.endDate!)
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

class _ProgramDetailsBody extends StatelessWidget {
  const _ProgramDetailsBody({
    required this.program,
    required this.dateLabel,
    required this.endDateLabel,
  });

  final Program program;
  final String dateLabel;
  final String? endDateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(program.name, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppChip(
                    label: program.goal.replaceAll('_', ' '),
                    emphasized: true,
                  ),
                  AppChip(label: program.status),
                  AppChip(
                    label: endDateLabel == null
                        ? 'Starts $dateLabel'
                        : '$dateLabel → $endDateLabel',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text('Exercises', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              if (program.exercises.isEmpty)
                Text(
                  'No exercises in this program.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.stone,
                  ),
                )
              else
                ...program.exercises.map(
                  (exercise) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ExerciseTile(exercise: exercise),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: FilledButton.icon(
            onPressed: () => context.go(
              AppRoutes.activeSessionPath(program.id),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start session'),
          ),
        ),
      ],
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise});

  final ProgramExercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rest = exercise.restSeconds != null
        ? '${exercise.restSeconds}s rest'
        : null;
    final duration = exercise.durationMinutes != null
        ? '${exercise.durationMinutes} min'
        : null;
    final meta = [
      '${exercise.sets} sets',
      exercise.reps,
      ?rest,
      ?duration,
    ].join(' · ');

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${exercise.order + 1}. ${exercise.exerciseName}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            meta,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.stone),
          ),
          if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              exercise.notes!,
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.stone),
            ),
          ],
        ],
      ),
    );
  }
}
