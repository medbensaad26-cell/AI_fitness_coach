import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/loading_view.dart';
import '../../programs/application/programs_controller.dart';
import '../../profile/application/profile_controller.dart';
import '../application/pending_onboarding.dart';

/// Post-signup welcome: confirm profile and optionally generate first program.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _generating = false;

  void _finish() {
    ref.read(pendingOnboardingProvider.notifier).complete();
    context.go(AppRoutes.home);
  }

  Future<void> _generateFirstProgram() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      await ref.read(programsListProvider.notifier).generate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your first program is ready')),
      );
      _finish();
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: profileAsync.when(
            loading: () => const LoadingView(message: 'Loading your profile…'),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    error is AppException
                        ? error.message
                        : 'Could not load profile',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _generating ? null : _finish,
                    child: const Text('Continue to home'),
                  ),
                ],
              ),
            ),
            data: (profile) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const BrandMark(),
                        const SizedBox(height: 28),
                        Text(
                          'Welcome${profile.name != null && profile.name!.isNotEmpty ? ', ${profile.name}' : ''}',
                          style: theme.textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Your coach is ready. Generate a first plan from your profile, or skip and explore home.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppTheme.stone,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        AppSurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your profile',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (profile.fitnessLevel != null)
                                    AppChip(
                                      label: profile.fitnessLevel!,
                                      emphasized: true,
                                    ),
                                  if (profile.primaryGoal != null)
                                    AppChip(
                                      label: profile.primaryGoal!
                                          .replaceAll('_', ' '),
                                    ),
                                  if (profile.trainingFrequency != null)
                                    AppChip(label: profile.trainingFrequency!),
                                  if (profile.availableEquipment != null &&
                                      profile.availableEquipment!.isNotEmpty)
                                    AppChip(
                                      label: profile.availableEquipment!,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _generating
                                    ? null
                                    : () {
                                        ref
                                            .read(
                                              pendingOnboardingProvider
                                                  .notifier,
                                            )
                                            .complete();
                                        context.go(AppRoutes.profile);
                                      },
                                child: const Text('Edit profile first'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        FilledButton.icon(
                          onPressed:
                              _generating ? null : _generateFirstProgram,
                          icon: _generating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: Text(
                            _generating
                                ? 'Generating (may take a few minutes)…'
                                : 'Generate my first program',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _generating ? null : _finish,
                          child: const Text('Skip for now'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
