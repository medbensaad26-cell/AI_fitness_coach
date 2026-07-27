import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../data/program_models.dart';

Future<void> showSuggestNextResultDialog(
  BuildContext context, {
  required SuggestNextResult result,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: const Text('Next program ready'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.program.name,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                result.rationale,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.stone,
                ),
              ),
              if (result.adaptations.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Adaptations', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: result.adaptations
                      .map((item) => AppChip(label: item, emphasized: true))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Stay on home'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go(AppRoutes.programDetailsPath(result.program.id));
            },
            child: const Text('Open program'),
          ),
        ],
      );
    },
  );
}
