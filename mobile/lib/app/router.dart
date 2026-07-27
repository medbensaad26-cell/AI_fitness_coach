import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_screens.dart';
import '../features/history/presentation/session_history_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/programs/presentation/program_details_screen.dart';
import '../features/sessions/presentation/active_session_screen.dart';
import 'routes.dart';

export 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.programDetails,
        builder: (context, state) => const ProgramDetailsScreen(),
      ),
      GoRoute(
        path: AppRoutes.activeSession,
        builder: (context, state) => const ActiveSessionScreen(),
      ),
      GoRoute(
        path: AppRoutes.sessionHistory,
        builder: (context, state) => const SessionHistoryScreen(),
      ),
    ],
  );
});
