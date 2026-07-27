import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/placeholder_screen.dart';

/// Active workout session placeholder — no live session logic yet.
class ActiveSessionScreen extends StatelessWidget {
  const ActiveSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Active workout',
      subtitle: 'Live session tracking will be connected later.',
      children: [
        FilledButton(
          onPressed: () => context.go(AppRoutes.sessionHistory),
          child: const Text('Finish (placeholder)'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Back to home'),
        ),
      ],
    );
  }
}
