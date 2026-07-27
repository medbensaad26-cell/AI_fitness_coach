import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../onboarding/application/pending_onboarding.dart';
import '../application/auth_controller.dart';
import '../data/auth_models.dart';

/// Multi-step registration matching backend `UserCreate`.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _limitationsController = TextEditingController();

  String? _sex;
  String? _fitnessLevel;
  String? _primaryGoal;
  String? _trainingFrequency;
  bool _obscurePassword = true;
  bool _submitting = false;
  int _step = 0;

  static const _stepCount = 4;
  static const _sexOptions = ['female', 'male', 'other'];
  static const _fitnessLevels = ['beginner', 'intermediate', 'advanced'];
  static const _goals = [
    'strength',
    'hypertrophy',
    'fat_loss',
    'endurance',
    'general_fitness',
  ];
  static const _frequencies = [
    '2x/week',
    '3x/week',
    '4x/week',
    '5x/week',
    '6x/week',
  ];

  static const _titles = [
    'Create your account',
    'About you',
    'Training goals',
    'Equipment & limits',
  ];

  static const _subtitles = [
    'Email and password to sign in later.',
    'Basics so the coach can personalize loads and volume.',
    'What you want to work toward each week.',
    'Optional context for safer, better programs.',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _equipmentController.dispose();
    _limitationsController.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    if (!_formKey.currentState!.validate()) return false;

    if (_step == 1 && _sex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select sex')),
      );
      return false;
    }
    if (_step == 2 &&
        (_fitnessLevel == null ||
            _primaryGoal == null ||
            _trainingFrequency == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all goal fields')),
      );
      return false;
    }
    return true;
  }

  Future<void> _next() async {
    if (!_validateCurrentStep()) return;
    if (_step < _stepCount - 1) {
      setState(() => _step += 1);
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _submit();
  }

  Future<void> _back() async {
    if (_step == 0) {
      ref.read(authControllerProvider.notifier).clearError();
      context.go(AppRoutes.login);
      return;
    }
    setState(() => _step -= 1);
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    if (!_validateCurrentStep()) return;

    setState(() => _submitting = true);
    try {
      ref.read(pendingOnboardingProvider.notifier).markPending();
      await ref.read(authControllerProvider.notifier).register(
            RegisterRequest(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              name: _nameController.text.trim(),
              age: int.parse(_ageController.text.trim()),
              sex: _sex!,
              heightCm: double.parse(_heightController.text.trim()),
              weightKg: double.parse(_weightController.text.trim()),
              fitnessLevel: _fitnessLevel!,
              primaryGoal: _primaryGoal!,
              trainingFrequency: _trainingFrequency!,
              availableEquipment: _equipmentController.text.trim(),
              limitations: _limitationsController.text.trim(),
            ),
          );
    } on AppException catch (error) {
      ref.read(pendingOnboardingProvider.notifier).complete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final busy = _submitting || auth.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${_step + 1} of $_stepCount'),
        leading: IconButton(
          tooltip: _step == 0 ? 'Back to login' : 'Previous step',
          icon: const Icon(Icons.arrow_back),
          onPressed: busy ? null : _back,
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StepProgress(step: _step, total: _stepCount),
                          const SizedBox(height: 20),
                          Text(
                            _titles[_step],
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _subtitles[_step],
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppTheme.stone,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _AccountStep(
                            emailController: _emailController,
                            passwordController: _passwordController,
                            obscurePassword: _obscurePassword,
                            busy: busy,
                            onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          _AboutStep(
                            nameController: _nameController,
                            ageController: _ageController,
                            heightController: _heightController,
                            weightController: _weightController,
                            sex: _sex,
                            sexOptions: _sexOptions,
                            busy: busy,
                            onSexChanged: (value) =>
                                setState(() => _sex = value),
                          ),
                          _GoalsStep(
                            fitnessLevel: _fitnessLevel,
                            primaryGoal: _primaryGoal,
                            trainingFrequency: _trainingFrequency,
                            fitnessLevels: _fitnessLevels,
                            goals: _goals,
                            frequencies: _frequencies,
                            busy: busy,
                            onFitnessChanged: (value) =>
                                setState(() => _fitnessLevel = value),
                            onGoalChanged: (value) =>
                                setState(() => _primaryGoal = value),
                            onFrequencyChanged: (value) =>
                                setState(() => _trainingFrequency = value),
                          ),
                          _ExtrasStep(
                            equipmentController: _equipmentController,
                            limitationsController: _limitationsController,
                            busy: busy,
                          ),
                        ],
                      ),
                    ),
                    if (auth.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          auth.errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                      child: FilledButton(
                        onPressed: busy ? null : _next,
                        child: busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _step == _stepCount - 1
                                    ? 'Create account'
                                    : 'Continue',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (index) {
        final active = index <= step;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: EdgeInsets.only(right: index == total - 1 ? 0 : 6),
            height: 4,
            decoration: BoxDecoration(
              color: active ? AppTheme.pine : AppTheme.mistDeep,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.busy,
    required this.onToggleObscure,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool busy;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      children: [
        TextFormField(
          controller: emailController,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty) return 'Email is required';
            if (!email.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: passwordController,
          enabled: !busy,
          obscureText: obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              onPressed: busy ? null : onToggleObscure,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Password is required';
            if (value.length < 6) return 'Use at least 6 characters';
            return null;
          },
        ),
      ],
    );
  }
}

class _AboutStep extends StatelessWidget {
  const _AboutStep({
    required this.nameController,
    required this.ageController,
    required this.heightController,
    required this.weightController,
    required this.sex,
    required this.sexOptions,
    required this.busy,
    required this.onSexChanged,
  });

  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final String? sex;
  final List<String> sexOptions;
  final bool busy;
  final ValueChanged<String?> onSexChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      children: [
        TextFormField(
          controller: nameController,
          enabled: !busy,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: ageController,
                enabled: !busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
                validator: (value) {
                  final age = int.tryParse(value?.trim() ?? '');
                  if (age == null || age <= 0) return 'Invalid';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: sex,
                decoration: const InputDecoration(labelText: 'Sex'),
                items: sexOptions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(option),
                      ),
                    )
                    .toList(),
                onChanged: busy ? null : onSexChanged,
                validator: (value) => value == null ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: heightController,
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Height (cm)'),
                validator: (value) {
                  final height = double.tryParse(value?.trim() ?? '');
                  if (height == null || height <= 0) return 'Invalid';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: weightController,
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
                validator: (value) {
                  final weight = double.tryParse(value?.trim() ?? '');
                  if (weight == null || weight <= 0) return 'Invalid';
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GoalsStep extends StatelessWidget {
  const _GoalsStep({
    required this.fitnessLevel,
    required this.primaryGoal,
    required this.trainingFrequency,
    required this.fitnessLevels,
    required this.goals,
    required this.frequencies,
    required this.busy,
    required this.onFitnessChanged,
    required this.onGoalChanged,
    required this.onFrequencyChanged,
  });

  final String? fitnessLevel;
  final String? primaryGoal;
  final String? trainingFrequency;
  final List<String> fitnessLevels;
  final List<String> goals;
  final List<String> frequencies;
  final bool busy;
  final ValueChanged<String?> onFitnessChanged;
  final ValueChanged<String?> onGoalChanged;
  final ValueChanged<String?> onFrequencyChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      children: [
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: fitnessLevel,
          decoration: const InputDecoration(labelText: 'Fitness level'),
          items: fitnessLevels
              .map(
                (option) => DropdownMenuItem(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: busy ? null : onFitnessChanged,
          validator: (value) => value == null ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: primaryGoal,
          decoration: const InputDecoration(labelText: 'Primary goal'),
          items: goals
              .map(
                (option) => DropdownMenuItem(
                  value: option,
                  child: Text(option.replaceAll('_', ' ')),
                ),
              )
              .toList(),
          onChanged: busy ? null : onGoalChanged,
          validator: (value) => value == null ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: trainingFrequency,
          decoration: const InputDecoration(labelText: 'Training frequency'),
          items: frequencies
              .map(
                (option) => DropdownMenuItem(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: busy ? null : onFrequencyChanged,
          validator: (value) => value == null ? 'Required' : null,
        ),
      ],
    );
  }
}

class _ExtrasStep extends StatelessWidget {
  const _ExtrasStep({
    required this.equipmentController,
    required this.limitationsController,
    required this.busy,
  });

  final TextEditingController equipmentController;
  final TextEditingController limitationsController;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      children: [
        TextFormField(
          controller: equipmentController,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Available equipment',
            hintText: 'e.g. dumbbells, gym',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: limitationsController,
          enabled: !busy,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Limitations',
            hintText: 'e.g. none, knee pain',
          ),
        ),
      ],
    );
  }
}
