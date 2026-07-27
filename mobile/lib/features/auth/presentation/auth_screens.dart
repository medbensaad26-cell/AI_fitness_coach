import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/placeholder_screen.dart';

/// Initial splash placeholder. Auth bootstrap is not implemented yet.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(child: LoadingView(message: 'AI Fitness Coach')),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Continue to login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Login placeholder — no real authentication yet.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Login',
      subtitle: 'Authentication will be connected in a later task.',
      children: [
        FilledButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Continue (placeholder)'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.go(AppRoutes.register),
          child: const Text('Create account'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go(AppRoutes.onboarding),
          child: const Text('Start onboarding'),
        ),
      ],
    );
  }
}

/// Register placeholder — no real registration yet.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Register',
      subtitle: 'Account creation will be connected in a later task.',
      children: [
        FilledButton(
          onPressed: () => context.go(AppRoutes.onboarding),
          child: const Text('Continue (placeholder)'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Back to login'),
        ),
      ],
    );
  }
}
