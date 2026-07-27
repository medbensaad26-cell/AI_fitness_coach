import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/coach_chat/presentation/coach_chat_overlay.dart';

/// Shows the floating coach chat only while the user is signed in.
class AuthenticatedCoachChatHost extends ConsumerWidget {
  const AuthenticatedCoachChatHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isAuthenticated) {
      return child;
    }
    return CoachChatOverlay(child: child);
  }
}
