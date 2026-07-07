import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/core/widgets/primary_button.dart';
import 'package:stride/features/onboarding/providers/onboarding_provider.dart';
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

  static const _stepCount = 4;

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
    final weight = double.tryParse(_weightController.text) ?? 70.0;

    ref.read(onboardingProvider.notifier).setHeightWeight(height, weight);

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

  Widget _buildHeightWeightStep() {
    return _StepContainer(
      step: 3,
      total: _stepCount,
      title: 'Tell us a bit about yourself',
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricField(_heightController, 'Height', 'cm')),
            const SizedBox(width: 14),
            Expanded(child: _buildMetricField(_weightController, 'Weight', 'kg')),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricField(TextEditingController controller, String label, String unit) {
    final theme = Theme.of(context);
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      step: 4,
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
