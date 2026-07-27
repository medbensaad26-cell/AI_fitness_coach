import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/placeholder_screen.dart';

/// Onboarding placeholder — no real profile setup yet.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Onboarding',
      subtitle: 'Profile and goal setup will be connected later.',
      children: [
        FilledButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Finish (placeholder)'),
        ),
      ],
    );
  }
}
