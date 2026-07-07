import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/core/widgets/primary_button.dart';
import 'package:stride/core/providers/preferences_provider.dart';
import 'package:stride/features/onboarding/providers/onboarding_provider.dart';
import 'package:stride/core/utils/formatters.dart';
import 'package:stride/theme/glass_container.dart';
import 'package:stride/features/tracking/presentation/tracking_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController(text: '25');

  static const _stepCount = 5;

  void _nextPage() {
    if (_currentPage < _stepCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() async {
    final height = double.tryParse(_heightController.text) ?? 170.0;
    var weight = double.tryParse(_weightController.text) ?? 70.0;
    final isKg = ref.read(isKgProvider);
    if (!isKg) {
      weight = lbsToKg(weight);
    }
    
    final age = int.tryParse(_ageController.text) ?? 25;

    ref.read(onboardingProvider.notifier).setHeightWeight(height, weight);
    
    // We update the gender in state on tap, but age from the controller
    final gender = ref.read(onboardingProvider).gender;
    ref.read(onboardingProvider.notifier).setGenderAge(
      gender.isEmpty ? 'Not specified' : gender, 
      age
    );

    final success = await ref.read(onboardingProvider.notifier).saveProfile();

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TrackingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(onboardingProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header: back button + progress
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 24, 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: _currentPage > 0
                        ? IconButton(
                            onPressed: _previousPage,
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                          ).animate().fadeIn(duration: 250.ms)
                        : null,
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_stepCount, (index) {
                        final isActive = _currentPage == index;
                        final isDone = index < _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive || isDone
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe to force button clicks
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildGoalStep(),
                  _buildExperienceStep(),
                  _buildGenderAgeStep(),
                  _buildHeightWeightStep(),
                  _buildActivityStep(),
                ],
              ),
            ),

            // Footer Navigation
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: PrimaryButton(
                text: _currentPage == _stepCount - 1 ? 'Get Started' : 'Next',
                isLoading: state.isSaving,
                onPressed: _nextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalStep() {
    return _StepContainer(
      step: 1,
      total: _stepCount,
      title: 'What is your primary goal?',
      children: [
        _buildOptionChip('Build Endurance', () {
          ref.read(onboardingProvider.notifier).setGoal('Endurance');
        }, ref.read(onboardingProvider).goal == 'Endurance'),
        _buildOptionChip('Lose Weight', () {
          ref.read(onboardingProvider.notifier).setGoal('Weight Loss');
        }, ref.read(onboardingProvider).goal == 'Weight Loss'),
        _buildOptionChip('Just for Fun', () {
          ref.read(onboardingProvider.notifier).setGoal('Fun');
        }, ref.read(onboardingProvider).goal == 'Fun'),
      ],
    );
  }

  Widget _buildExperienceStep() {
    return _StepContainer(
      step: 2,
      total: _stepCount,
      title: 'What is your experience level?',
      children: [
        _buildOptionChip('Beginner', () {
          ref.read(onboardingProvider.notifier).setExperienceLevel('Beginner');
        }, ref.read(onboardingProvider).experienceLevel == 'Beginner'),
        _buildOptionChip('Intermediate', () {
          ref.read(onboardingProvider.notifier).setExperienceLevel('Intermediate');
        }, ref.read(onboardingProvider).experienceLevel == 'Intermediate'),
        _buildOptionChip('Advanced', () {
          ref.read(onboardingProvider.notifier).setExperienceLevel('Advanced');
        }, ref.read(onboardingProvider).experienceLevel == 'Advanced'),
      ],
    );
  }

  Widget _buildGenderAgeStep() {
    return _StepContainer(
      step: 3,
      total: _stepCount,
      title: 'What is your gender & age?',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildGenderIconChip('Male', Icons.male),
            _buildGenderIconChip('Female', Icons.female),
            _buildGenderIconChip('Other', Icons.transgender),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildMetricField(_ageController, 'Age', 'yrs', isInt: true)),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderIconChip(String label, IconData icon) {
    final isSelected = ref.read(onboardingProvider).gender == label;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    
    return InkWell(
      onTap: () {
        ref.read(onboardingProvider.notifier).setGenderAge(label, int.tryParse(_ageController.text) ?? 25);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 90,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.15) : onSurface.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : onSurface.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: isSelected ? theme.colorScheme.primary : onSurface.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? onSurface : onSurface.withValues(alpha: 0.6),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeightWeightStep() {
    final isKm = ref.watch(isKmProvider);
    final isKg = ref.watch(isKgProvider);
    final theme = Theme.of(context);

    return _StepContainer(
      step: 4,
      total: _stepCount,
      title: 'Tell us a bit about yourself',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                Text('Distance Units', style: theme.textTheme.labelSmall),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('km')),
                    ButtonSegment(value: false, label: Text('mi')),
                  ],
                  selected: {isKm},
                  onSelectionChanged: (set) => ref.read(isKmProvider.notifier).setKm(set.first),
                  showSelectedIcon: false,
                ),
              ],
            ),
            Column(
              children: [
                Text('Weight Units', style: theme.textTheme.labelSmall),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('kg')),
                    ButtonSegment(value: false, label: Text('lbs')),
                  ],
                  selected: {isKg},
                  onSelectionChanged: (set) => ref.read(isKgProvider.notifier).setKg(set.first),
                  showSelectedIcon: false,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
        const SizedBox(height: 16),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _heightController,
          builder: (context, value, child) {
            final cm = double.tryParse(value.text) ?? 0.0;
            return Row(
              children: [
                Expanded(
                  flex: 6,
                  child: _buildMetricField(_heightController, 'Height', 'cm'),
                ),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: Text(
                      formatHeightToFtIn(cm),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _weightController,
          builder: (context, value, child) {
            final weight = double.tryParse(value.text) ?? 0.0;
            final conversionText = isKg 
                ? '${kgToLbs(weight).toStringAsFixed(1)} lbs' 
                : '${lbsToKg(weight).toStringAsFixed(1)} kg';
            
            return Row(
              children: [
                Expanded(
                  flex: 6,
                  child: _buildMetricField(_weightController, 'Weight', isKg ? 'kg' : 'lbs'),
                ),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: Text(
                      weight > 0 ? conversionText : '--',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetricField(TextEditingController controller, String label, String unit, {bool isInt = false}) {
    final theme = Theme.of(context);
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          TextField(
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
        ],
      ),
    );
  }

  Widget _buildActivityStep() {
    return _StepContainer(
      step: 5,
      total: _stepCount,
      title: 'How active are you normally?',
      children: [
        _buildOptionChip('Sedentary', () {
          ref.read(onboardingProvider.notifier).setActivityLevel('Sedentary');
        }, ref.read(onboardingProvider).activityLevel == 'Sedentary'),
        _buildOptionChip('Lightly Active', () {
          ref.read(onboardingProvider.notifier).setActivityLevel('Light');
        }, ref.read(onboardingProvider).activityLevel == 'Light'),
        _buildOptionChip('Very Active', () {
          ref.read(onboardingProvider.notifier).setActivityLevel('Active');
        }, ref.read(onboardingProvider).activityLevel == 'Active'),
      ],
    );
  }

  Widget _buildOptionChip(String label, VoidCallback onTap, bool isSelected) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          onTap();
          setState(() {}); // trigger rebuild for color change since we read provider directly in the loop above
        },
        borderRadius: BorderRadius.circular(18),
        child: GlassContainer(
          borderRadius: 18,
          padding: const EdgeInsets.all(20),
          backgroundColor: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : onSurface.withValues(alpha: 0.05),
          borderColor: isSelected
              ? theme.colorScheme.primary
              : onSurface.withValues(alpha: 0.1),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 17,
                    color: isSelected ? theme.colorScheme.primary : onSurface,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
              else
                Icon(Icons.circle_outlined, color: onSurface.withValues(alpha: 0.25)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepContainer extends StatelessWidget {
  final int step;
  final int total;
  final String title;
  final List<Widget> children;

  const _StepContainer({
    required this.step,
    required this.total,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Text(
            'STEP $step OF $total',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ).animate().fadeIn(duration: 350.ms),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.displayLarge?.copyWith(fontSize: 30),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0),
          const SizedBox(height: 40),
          ...children.animate(interval: 100.ms).fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0),
        ],
      ),
    );
  }
}
