import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../programs/application/programs_controller.dart';
import '../../programs/data/program_models.dart';
import '../../programs/presentation/suggest_next_dialog.dart';

/// Home hub: lists programs and can trigger AI generation.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _busyAi = false;

  Future<void> _generate() async {
    if (_busyAi) return;
    setState(() => _busyAi = true);
    try {
      await ref.read(programsListProvider.notifier).generate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Program generated')),
      );
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _busyAi = false);
    }
  }

  Future<void> _suggestNext() async {
    if (_busyAi) return;
    setState(() => _busyAi = true);
    try {
      final result =
          await ref.read(programsListProvider.notifier).suggestNext();
      if (!mounted) return;
      await showSuggestNextResultDialog(context, result: result);
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _busyAi = false);
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final programsAsync = ref.watch(programsListProvider);
    final hasPrograms = programsAsync.maybeWhen(
      data: (programs) => programs.isNotEmpty,
      orElse: () => false,
    );

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Fitness Coach',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppTheme.pineDeep,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Text(
                            'Home',
                            style: theme.textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                    if (hasPrograms) ...[
                      IconButton(
                        tooltip: 'Suggest next program',
                        onPressed: _busyAi ? null : _suggestNext,
                        icon: const Icon(Icons.trending_up_rounded),
                      ),
                      IconButton(
                        tooltip: 'Generate program',
                        onPressed: _busyAi ? null : _generate,
                        icon: _busyAi
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                      ),
                    ],
                    IconButton(
                      tooltip: 'Profile',
                      onPressed: () => context.go(AppRoutes.profile),
                      icon: const Icon(Icons.person_outline_rounded),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(authControllerProvider.notifier).logout(),
                      child: const Text('Log out'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: programsAsync.when(
                  loading: () =>
                      const LoadingView(message: 'Loading programs…'),
                  error: (error, _) => ErrorView(
                    message: error is AppException
                        ? error.message
                        : 'Failed to load programs',
                    onRetry: () =>
                        ref.read(programsListProvider.notifier).refresh(),
                  ),
                  data: (programs) {
                    if (programs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Your programs',
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Generate a plan from your profile to get started.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppTheme.stone,
                              ),
                            ),
                            const Expanded(
                              child: EmptyView(
                                message: 'No programs yet.',
                                icon: Icons.fitness_center_outlined,
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _busyAi ? null : _generate,
                              icon: _busyAi
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.auto_awesome),
                              label: Text(
                                _busyAi
                                    ? 'Generating (may take a few minutes)…'
                                    : 'Generate program',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () =>
                                  context.go(AppRoutes.sessionHistory),
                              child: const Text('View session history'),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () =>
                          ref.read(programsListProvider.notifier).refresh(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: programs.length + 1,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your programs',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap a program to see exercises and start a session.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.stone,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    FilledButton.tonalIcon(
                                      onPressed: _busyAi ? null : _suggestNext,
                                      icon: const Icon(
                                        Icons.trending_up_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _busyAi
                                            ? 'Working…'
                                            : 'Suggest next program',
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          context.go(AppRoutes.sessionHistory),
                                      icon: const Icon(Icons.history, size: 18),
                                      label: const Text('Session history'),
                                    ),
                                  ],
                                ),                              ],
                            );
                          }

                          final program = programs[index - 1];
                          return _ProgramCard(
                            program: program,
                            dateLabel: _formatDate(program.startDate),
                            onTap: () => context.go(
                              AppRoutes.programDetailsPath(program.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.program,
    required this.dateLabel,
    required this.onTap,
  });

  final Program program;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSurface(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.pine.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppTheme.pineDeep,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.name,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    AppChip(
                      label: program.goal.replaceAll('_', ' '),
                      emphasized: true,
                    ),
                    AppChip(label: program.status),
                    AppChip(
                      label:
                          '${program.exercises.length} exercises · $dateLabel',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.stone),
        ],
      ),
    );
  }
}
