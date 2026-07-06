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

  final _goals = ['Endurance', 'Weight Loss', 'Fun'];
  final _experiences = ['Beginner', 'Intermediate', 'Advanced'];
  final _activities = ['Sedentary', 'Light', 'Active'];

  @override
  void initState() {
    super.initState();
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

  Widget _buildOptionChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          backgroundColor: isSelected 
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : const Color(0x1AFFFFFF),
          borderColor: isSelected
              ? Theme.of(context).colorScheme.primary
              : const Color(0x33FFFFFF),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white54,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'BODY METRICS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GlassContainer(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text('HEIGHT', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54)),
                              TextFormField(
                                controller: _heightController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  suffixText: 'cm',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GlassContainer(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text('WEIGHT', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white54)),
                              TextFormField(
                                controller: _weightController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  suffixText: 'kg',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  Text(
                    'PRIMARY GOAL',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 16),
                  ..._goals.map((g) => _buildOptionChip(
                        g,
                        _selectedGoal == g,
                        () => setState(() => _selectedGoal = g),
                      )),
                  const SizedBox(height: 24),
                  
                  Text(
                    'EXPERIENCE LEVEL',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 16),
                  ..._experiences.map((e) => _buildOptionChip(
                        e,
                        _selectedExperience == e,
                        () => setState(() => _selectedExperience = e),
                      )),
                  const SizedBox(height: 24),
                  
                  Text(
                    'ACTIVITY LEVEL',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 16),
                  ..._activities.map((a) => _buildOptionChip(
                        a,
                        _selectedActivity == a,
                        () => setState(() => _selectedActivity = a),
                      )),
                  
                  const SizedBox(height: 48),
                  PrimaryButton(
                    text: 'Save Changes',
                    isLoading: profileState.isSaving,
                    onPressed: _saveProfile,
                  ),
                ],
              ),
            ),
          ));
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
