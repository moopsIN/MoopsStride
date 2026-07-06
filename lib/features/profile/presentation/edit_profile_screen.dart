import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/core/widgets/primary_button.dart';
import 'package:stride/features/profile/providers/profile_provider.dart';
import 'package:stride/theme/glass_container.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String? _selectedGoal;
  String? _selectedExperience;
  String? _selectedActivity;

  final _goals = ['Lose Weight', 'Build Endurance', 'Stay Healthy', 'Train for Race'];
  final _experiences = ['Beginner', 'Intermediate', 'Advanced'];
  final _activities = ['Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active'];

  @override
  void initState() {
    super.initState();
    // Delay setting values to allow the provider to load if it hasn't
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(profileProvider).value;
      if (state != null) {
        setState(() {
          _heightController.text = state.height.toString();
          _weightController.text = state.weight.toString();
          if (_goals.contains(state.goal)) _selectedGoal = state.goal;
          if (_experiences.contains(state.experienceLevel)) _selectedExperience = state.experienceLevel;
          if (_activities.contains(state.activityLevel)) _selectedActivity = state.activityLevel;
        });
      }
    });
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final height = double.tryParse(_heightController.text) ?? 170.0;
    final weight = double.tryParse(_weightController.text) ?? 70.0;

    final success = await ref.read(profileProvider.notifier).updateProfile(
      goal: _selectedGoal ?? '',
      experienceLevel: _selectedExperience ?? '',
      height: height,
      weight: weight,
      activityLevel: _selectedActivity ?? '',
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      Navigator.of(context).pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: state.when(
        data: (profileState) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'PERSONAL DETAILS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 16),
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedGoal,
                          decoration: const InputDecoration(labelText: 'Primary Goal'),
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          items: _goals.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                          onChanged: (val) => setState(() => _selectedGoal = val),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedExperience,
                          decoration: const InputDecoration(labelText: 'Experience Level'),
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          items: _experiences.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) => setState(() => _selectedExperience = val),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedActivity,
                          decoration: const InputDecoration(labelText: 'Activity Level'),
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          items: _activities.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                          onChanged: (val) => setState(() => _selectedActivity = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'BODY METRICS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 16),
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Height',
                              suffixText: 'cm',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Weight',
                              suffixText: 'kg',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  PrimaryButton(
                    text: 'Save Changes',
                    isLoading: profileState.isSaving,
                    onPressed: _saveProfile,
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
