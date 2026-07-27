import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True after signup until the user finishes the welcome/onboarding screen.
class PendingOnboardingController extends Notifier<bool> {
  @override
  bool build() => false;

  void markPending() => state = true;

  void complete() => state = false;
}

final pendingOnboardingProvider =
    NotifierProvider<PendingOnboardingController, bool>(
      PendingOnboardingController.new,
    );
