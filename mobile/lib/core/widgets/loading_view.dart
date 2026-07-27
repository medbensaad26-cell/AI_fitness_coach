import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'app_chrome.dart';

/// Centered loading indicator with an optional message.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null && message!.contains('coach')) ...[
            const BrandMark(compact: true),
            const SizedBox(height: 28),
          ],
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null) ...[
            const SizedBox(height: 18),
            Text(
              message!,
              style: theme.textTheme.bodyLarge?.copyWith(color: AppTheme.stone),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
