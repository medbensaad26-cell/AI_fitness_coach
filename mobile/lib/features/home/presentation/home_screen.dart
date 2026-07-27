import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/placeholder_screen.dart';

/// Home placeholder — no program/API data yet.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Home',
      subtitle: 'Your coaching hub will appear here.',
      children: [
        const Expanded(
          child: EmptyView(
            message: 'No programs loaded yet.',
            icon: Icons.fitness_center_outlined,
          ),
        ),
        FilledButton(
          onPressed: () => context.go(AppRoutes.programDetails),
          child: const Text('Open program details'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.go(AppRoutes.activeSession),
          child: const Text('Start workout session'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go(AppRoutes.sessionHistory),
          child: const Text('View session history'),
        ),
      ],
    );
  }
}
