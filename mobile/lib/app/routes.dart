/// Central route path constants.
abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const profile = '/profile';
  static const programDetails = '/programs/:programId';
  static const activeSession = '/sessions/active/:programId';
  static const sessionHistory = '/history';
  static const sessionDetails = '/history/:sessionId';

  static String programDetailsPath(String programId) => '/programs/$programId';

  static String activeSessionPath(String programId) =>
      '/sessions/active/$programId';

  static String sessionDetailsPath(String sessionId) => '/history/$sessionId';
}
