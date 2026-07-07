import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/core/widgets/primary_button.dart';
import 'package:stride/features/profile/providers/profile_provider.dart';
import 'package:stride/core/providers/preferences_provider.dart';
import 'package:stride/core/utils/formatters.dart';
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
  final _ageController = TextEditingController();

  String? _selectedGoal;
  String? _selectedExperience;
  String? _selectedActivity;
  String? _selectedGender;

  final _goals = ['Endurance', 'Weight Loss', 'Fun'];
  final _experiences = ['Beginner', 'Intermediate', 'Advanced'];
  final _activities = ['Sedentary', 'Light', 'Active'];
  final _genders = ['Male', 'Female', 'Other', 'Not specified'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(profileProvider).value;
      if (state != null) {
        setState(() {
          _heightController.text = state.height.toString();
          
          final isKg = ref.read(isKgProvider);
          final displayWeight = isKg ? state.weight : kgToLbs(state.weight);
          _weightController.text = displayWeight.toStringAsFixed(1);
          
          _ageController.text = state.age.toString();
          if (_goals.contains(state.goal)) _selectedGoal = state.goal;
          if (_experiences.contains(state.experienceLevel)) _selectedExperience = state.experienceLevel;
          if (_activities.contains(state.activityLevel)) _selectedActivity = state.activityLevel;
          if (_genders.contains(state.gender)) _selectedGender = state.gender;
        });
      }
    });
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final height = double.tryParse(_heightController.text) ?? 170.0;
    var weight = double.tryParse(_weightController.text) ?? 70.0;
    
    final isKg = ref.read(isKgProvider);
    if (!isKg) {
      weight = lbsToKg(weight);
    }
    
    final age = int.tryParse(_ageController.text) ?? 25;

    final success = await ref.read(profileProvider.notifier).updateProfile(
      goal: _selectedGoal ?? '',
      experienceLevel: _selectedExperience ?? '',
      gender: _selectedGender ?? '',
      age: age,
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

  Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildOptionChip(String label, bool isSelected, VoidCallback onTap) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: GlassContainer(
          borderRadius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          backgroundColor: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : onSurface.withValues(alpha: 0.05),
          borderColor: isSelected
              ? theme.colorScheme.primary
              : onSurface.withValues(alpha: 0.1),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? theme.colorScheme.primary : onSurface.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isSelected ? onSurface : onSurface.withValues(alpha: 0.75),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricField(
      BuildContext context, String label, TextEditingController controller, String unit, {bool isInt = false, String? subtitle}) {
    final theme = Theme.of(context);
    return Expanded(
      child: GlassContainer(
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
              textAlign: TextAlign.center,
              style: theme.textTheme.displayLarge?.copyWith(fontSize: 26),
              decoration: InputDecoration(
                border: InputBorder.none,
                suffixText: unit,
                suffixStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            if (subtitle != null) ...[
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(profileProvider);
    final isKg = ref.watch(isKgProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: state.when(
        data: (profileState) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionLabel(context, 'BODY METRICS'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _heightController,
                          builder: (context, value, child) {
                            final cm = double.tryParse(value.text) ?? 0.0;
                            return _buildMetricField(context, 'HEIGHT', _heightController, 'cm', subtitle: formatHeightToFtIn(cm));
                          },
                        ),
                        const SizedBox(width: 14),
                        _buildMetricField(context, 'WEIGHT', _weightController, isKg ? 'kg' : 'lbs'),
                      ],
                    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08),

                    const SizedBox(height: 24),
                    _sectionLabel(context, 'PERSONAL DETAILS'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetricField(context, 'AGE', _ageController, 'yrs', isInt: true),
                        const SizedBox(width: 14),
                        Expanded(
                          child: GlassContainer(
                            borderRadius: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(
                              children: [
                                Text(
                                  'GENDER',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedGender,
                                    isExpanded: true,
                                    alignment: Alignment.center,
                                    dropdownColor: theme.colorScheme.surface,
                                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.primary),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    items: _genders.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (newValue) {
                                      setState(() {
                                        _selectedGender = newValue;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 350.ms, delay: 50.ms).slideY(begin: 0.08),
                    const SizedBox(height: 28),

                    _sectionLabel(context, 'PRIMARY GOAL'),
                    ..._goals.map((g) => _buildOptionChip(
                          g,
                          _selectedGoal == g,
                          () => setState(() => _selectedGoal = g),
                        )),
                    const SizedBox(height: 18),

                    _sectionLabel(context, 'EXPERIENCE LEVEL'),
                    ..._experiences.map((e) => _buildOptionChip(
                          e,
                          _selectedExperience == e,
                          () => setState(() => _selectedExperience = e),
                        )),
                    const SizedBox(height: 18),

                    _sectionLabel(context, 'ACTIVITY LEVEL'),
                    ..._activities.map((a) => _buildOptionChip(
                          a,
                          _selectedActivity == a,
                          () => setState(() => _selectedActivity = a),
                        )),

                    const SizedBox(height: 36),
                    PrimaryButton(
                      text: 'Save Changes',
                      isLoading: profileState.isSaving,
                      onPressed: _saveProfile,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: theme.textTheme.bodyMedium),
        ),
      ),
    );
  }
}
