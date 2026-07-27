import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Soft mist gradient backdrop used across polished screens.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF4F9F6),
            AppTheme.mist,
            AppTheme.mistDeep,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// Interactive list/tile surface (home programs, history, exercises).
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final content = Padding(padding: padding, child: child);

    return Material(
      color: Colors.white.withValues(alpha: 0.82),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: AppTheme.mistDeep.withValues(alpha: 0.9)),
      ),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: content,
            ),
    );
  }
}

/// Compact status / meta chip.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized
            ? AppTheme.pine.withValues(alpha: 0.12)
            : AppTheme.mistDeep.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: emphasized ? AppTheme.pineDeep : AppTheme.stone,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Brand mark used on auth / splash.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = compact ? 44.0 : 64.0;

    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.pine, AppTheme.pineDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.pine.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.fitness_center_rounded,
            color: Colors.white,
            size: compact ? 22 : 30,
          ),
        ),
        SizedBox(height: compact ? 12 : 18),
        Text(
          'AI Fitness Coach',
          style: (compact ? theme.textTheme.titleLarge : theme.textTheme.headlineMedium)
              ?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppTheme.ink,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
