import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/placeholder_screen.dart';

/// Session history placeholder — no history API integration yet.
class SessionHistoryScreen extends StatelessWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Session history',
      subtitle: 'Past workouts will appear here.',
      children: [
        const Expanded(
          child: EmptyView(
            message: 'No session history yet.',
            icon: Icons.history,
          ),
        ),
        TextButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Back to home'),
        ),
      ],
    );
  }
}
