import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/auth_screens.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/history/presentation/session_details_screen.dart';
import '../features/history/presentation/session_history_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/application/pending_onboarding.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/programs/presentation/program_details_screen.dart';
import '../features/sessions/presentation/active_session_screen.dart';
import 'go_router_refresh.dart';
import 'routes.dart';

export 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterRefreshNotifier();
  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    refresh.refresh();
  });
  ref.listen<bool>(pendingOnboardingProvider, (previous, next) {
    refresh.refresh();
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final pendingOnboarding = ref.read(pendingOnboardingProvider);
      final location = state.matchedLocation;
      final isSplash = location == AppRoutes.splash;
      final isPublicAuth =
          location == AppRoutes.login || location == AppRoutes.register;
      final isOnboarding = location == AppRoutes.onboarding;

      if (auth.isLoading) {
        return isSplash ? null : AppRoutes.splash;
      }

      if (auth.isAuthenticated) {
        if (pendingOnboarding && !isOnboarding) {
          return AppRoutes.onboarding;
        }
        if (!pendingOnboarding && isOnboarding) {
          return AppRoutes.home;
        }
        if (isSplash || isPublicAuth) {
          return pendingOnboarding
              ? AppRoutes.onboarding
              : AppRoutes.home;
        }
        return null;
      }

      // Unauthenticated
      if (isSplash) {
        return AppRoutes.login;
      }
      if (isPublicAuth) {
        return null;
      }
      return AppRoutes.login;
    },
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
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.programDetails,
        builder: (context, state) {
          final programId = state.pathParameters['programId'] ?? '';
          return ProgramDetailsScreen(programId: programId);
        },
      ),
      GoRoute(
        path: AppRoutes.activeSession,
        builder: (context, state) {
          final programId = state.pathParameters['programId'] ?? '';
          return ActiveSessionScreen(programId: programId);
        },
      ),
      GoRoute(
        path: AppRoutes.sessionHistory,
        builder: (context, state) => const SessionHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.sessionDetails,
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId'] ?? '';
          return SessionDetailsScreen(sessionId: sessionId);
        },
      ),
    ],
  );
});
