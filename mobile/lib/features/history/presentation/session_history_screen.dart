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
import '../../sessions/data/session_models.dart';
import '../../sessions/data/sessions_repository.dart';

/// Lists saved workout sessions for the signed-in user.
class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

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
    final sessionsAsync = ref.watch(sessionHistoryProvider);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back to home',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.go(AppRoutes.home),
                    ),
                    Expanded(
                      child: Text(
                        'Session history',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: sessionsAsync.when(
                  loading: () =>
                      const LoadingView(message: 'Loading history…'),
                  error: (error, _) => ErrorView(
                    message: error is AppException
                        ? error.message
                        : 'Failed to load sessions',
                    onRetry: () => ref.invalidate(sessionHistoryProvider),
                  ),
                  data: (sessions) {
                    if (sessions.isEmpty) {
                      return const EmptyView(
                        message: 'No session history yet.',
                        icon: Icons.history,
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(sessionHistoryProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: sessions.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          return _SessionTile(
                            session: session,
                            dateLabel: _formatDateTime(session.startTime),
                            onTap: () => context.go(
                              AppRoutes.sessionDetailsPath(session.id),
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

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.dateLabel,
    required this.onTap,
  });

  final WorkoutSession session;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feeling = session.overallFeeling;
    final fatigue = session.fatigueLevel;
    final duration = session.durationMinutes;

    return AppSurface(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateLabel, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (duration != null) AppChip(label: '$duration min'),
                    AppChip(label: '${session.exercises.length} exercises'),
                    if (feeling != null)
                      AppChip(label: 'feeling $feeling/5', emphasized: true),
                    if (fatigue != null) AppChip(label: 'fatigue $fatigue/5'),
                  ],
                ),
                if (session.comments != null &&
                    session.comments!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    session.comments!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.stone,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.stone),
        ],
      ),
    );
  }
}

final sessionHistoryProvider =
    FutureProvider.autoDispose<List<WorkoutSession>>((ref) {
  return ref.watch(sessionsRepositoryProvider).listMine();
});
