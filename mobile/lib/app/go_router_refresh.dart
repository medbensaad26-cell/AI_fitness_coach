import 'package:flutter/foundation.dart';

/// Bridges Riverpod auth updates into [GoRouter.refreshListenable].
class GoRouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
