import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/profile_controller.dart';
import '../data/profile_models.dart';

/// View and edit the authenticated user's fitness profile.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          tooltip: 'Back to home',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: profileAsync.when(
            loading: () => const LoadingView(message: 'Loading profile…'),
            error: (error, _) => ErrorView(
              message: error is AppException
                  ? error.message
                  : 'Failed to load profile',
              onRetry: () => ref.read(profileProvider.notifier).refresh(),
            ),
            data: (profile) => _ProfileForm(
              key: ValueKey(
                '${profile.id}-${profile.updatedAt?.toIso8601String() ?? ''}',
              ),
              profile: profile,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({super.key, required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _equipmentController;
  late final TextEditingController _limitationsController;
  late final TextEditingController _timeController;

  late String? _sex;
  late String? _fitnessLevel;
  late String? _primaryGoal;
  late String? _trainingFrequency;
  bool _submitting = false;

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

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController = TextEditingController(text: profile.name ?? '');
    _ageController = TextEditingController(text: profile.age?.toString() ?? '');
    _heightController =
        TextEditingController(text: profile.heightCm?.toString() ?? '');
    _weightController =
        TextEditingController(text: profile.weightKg?.toString() ?? '');
    _equipmentController =
        TextEditingController(text: profile.availableEquipment ?? '');
    _limitationsController =
        TextEditingController(text: profile.limitations ?? '');
    _timeController = TextEditingController(
      text: profile.availableTimeMinutes?.toString() ?? '',
    );
    _sex = profile.sex;
    _fitnessLevel = profile.fitnessLevel;
    _primaryGoal = profile.primaryGoal;
    _trainingFrequency = profile.trainingFrequency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _equipmentController.dispose();
    _limitationsController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sex == null ||
        _fitnessLevel == null ||
        _primaryGoal == null ||
        _trainingFrequency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }

    final timeText = _timeController.text.trim();
    final availableTime = timeText.isEmpty ? null : int.tryParse(timeText);

    setState(() => _submitting = true);
    try {
      await ref.read(profileProvider.notifier).save(
            ProfileUpdate(
              name: _nameController.text.trim(),
              age: int.parse(_ageController.text.trim()),
              sex: _sex,
              heightCm: double.parse(_heightController.text.trim()),
              weightKg: double.parse(_weightController.text.trim()),
              fitnessLevel: _fitnessLevel,
              primaryGoal: _primaryGoal,
              trainingFrequency: _trainingFrequency,
              availableEquipment: _equipmentController.text.trim(),
              limitations: _limitationsController.text.trim(),
              availableTimeMinutes: availableTime,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    } on AppException catch (error) {
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
    final profile = widget.profile;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your training profile',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep this up to date so generate and coach stay accurate.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.stone,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  profile.email,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.pineDeep,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  enabled: !_submitting,
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
                        controller: _ageController,
                        enabled: !_submitting,
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
                        value: _dropdownValue(_sex, _sexOptions),
                        decoration: const InputDecoration(labelText: 'Sex'),
                        items: _itemsFor(_sex, _sexOptions),
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _sex = value),
                        validator: (value) =>
                            value == null ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _heightController,
                        enabled: !_submitting,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Height (cm)'),
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
                        controller: _weightController,
                        enabled: !_submitting,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Weight (kg)'),
                        validator: (value) {
                          final weight = double.tryParse(value?.trim() ?? '');
                          if (weight == null || weight <= 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _dropdownValue(_fitnessLevel, _fitnessLevels),
                  decoration: const InputDecoration(labelText: 'Fitness level'),
                  items: _itemsFor(_fitnessLevel, _fitnessLevels),
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _fitnessLevel = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _dropdownValue(_primaryGoal, _goals),
                  decoration: const InputDecoration(labelText: 'Primary goal'),
                  items: _itemsFor(
                    _primaryGoal,
                    _goals,
                    labelOf: (o) => o.replaceAll('_', ' '),
                  ),
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _primaryGoal = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _dropdownValue(_trainingFrequency, _frequencies),
                  decoration:
                      const InputDecoration(labelText: 'Training frequency'),
                  items: _itemsFor(_trainingFrequency, _frequencies),
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _trainingFrequency = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _timeController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Available time (minutes)',
                    hintText: 'e.g. 45',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final minutes = int.tryParse(text);
                    if (minutes == null || minutes <= 0) {
                      return 'Must be greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _equipmentController,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: 'Available equipment',
                    hintText: 'e.g. dumbbells, gym',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _limitationsController,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: 'Limitations',
                    hintText: 'e.g. none, knee pain',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _save,
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _dropdownValue(String? current, List<String> options) {
    if (current == null) return null;
    return current;
  }

  List<DropdownMenuItem<String>> _itemsFor(
    String? current,
    List<String> options, {
    String Function(String)? labelOf,
  }) {
    final label = labelOf ?? (String value) => value;
    final values = [...options];
    if (current != null && !values.contains(current)) {
      values.insert(0, current);
    }
    return values
        .map(
          (option) => DropdownMenuItem(
            value: option,
            child: Text(label(option)),
          ),
        )
        .toList();
  }
}
