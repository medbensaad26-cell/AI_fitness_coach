import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/placeholder_screen.dart';

/// Program details placeholder — no program API integration yet.
class ProgramDetailsScreen extends StatelessWidget {
  const ProgramDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Program details',
      subtitle: 'Program content will be loaded from the API later.',
      children: [
        FilledButton(
          onPressed: () => context.go(AppRoutes.activeSession),
          child: const Text('Start session'),
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
