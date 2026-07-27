import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'authenticated_coach_chat_host.dart';
import 'router.dart';
import 'theme.dart';

/// Root application widget wired with Riverpod + GoRouter.
class AiFitnessCoachApp extends ConsumerWidget {
  const AiFitnessCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'AI Fitness Coach',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        return AuthenticatedCoachChatHost(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
