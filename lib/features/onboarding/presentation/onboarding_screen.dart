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

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
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
    final state = ref.watch(onboardingProvider);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index 
                          ? Theme.of(context).colorScheme.primary 
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
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
              padding: const EdgeInsets.all(24.0),
              child: PrimaryButton(
                text: _currentPage == 3 ? 'Get Started' : 'Next',
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
      title: 'Tell us a bit about yourself',
      children: [
        TextField(
          controller: _heightController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Height (cm)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _weightController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Weight (kg)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityStep() {
    return _StepContainer(
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          onTap();
          setState(() {}); // trigger rebuild for color change since we read provider directly in the loop above
        },
        borderRadius: BorderRadius.circular(16),
        child: GlassContainer(
          padding: const EdgeInsets.all(20),
          backgroundColor: isSelected 
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : const Color(0x1AFFFFFF),
          borderColor: isSelected
              ? Theme.of(context).colorScheme.primary
              : const Color(0x33FFFFFF),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepContainer extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _StepContainer({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            title,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0),
          const SizedBox(height: 48),
          ...children.animate(interval: 100.ms).fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0),
        ],
      ),
    );
  }
}
