import 'package:flutter/material.dart';
import 'package:stride/theme/notebook_background.dart';
import 'package:stride/core/widgets/moop.dart';
import 'package:stride/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/core/widgets/primary_button.dart';
import 'package:stride/core/providers/preferences_provider.dart';
import 'package:stride/features/onboarding/providers/onboarding_provider.dart';
import 'package:stride/core/utils/formatters.dart';
import 'package:stride/theme/brutal_card.dart';
import 'package:stride/features/tracking/presentation/tracking_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _heightController = TextEditingController(text: '170');
  final _weightController = TextEditingController(text: '70');
  final _ageController = TextEditingController(text: '25');

  static const _stepCount = 5;

  void _nextPage() {
    FocusScope.of(context).unfocus();
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
    FocusScope.of(context).unfocus();
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
    final state = ref.watch(onboardingProvider);

    return Scaffold(
      body: NotebookBackground(
        seed: 2,
        child: SafeArea(
          child: Column(
            children: [
              // Header: back button + progress
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 24, 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      height: 48,
                      child: _currentPage > 0
                          ? BrutalCard(
                              width: 44,
                              height: 44,
                              borderRadius: 22,
                              shadow: 3,
                              color: context.stride.surface,
                              onTap: _previousPage,
                              child: Icon(Icons.arrow_back_rounded, size: 22, color: context.stride.ink),
                            )
                          : null,
                    ),
                    Expanded(
                      child: Row(
                        children: List.generate(_stepCount, (index) {
                          final c = context.stride;
                          final reached = index <= _currentPage;
                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              height: 12,
                              decoration: BoxDecoration(
                                color: reached ? c.go : c.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: c.outline, width: 2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
                child: PrimaryButton(
                  text: _currentPage == _stepCount - 1 ? 'Get Started' : 'Next',
                  isLoading: state.isSaving,
                  onPressed: _nextPage,
                ),
              ),
            ],
          ),
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
    final c = context.stride;
    final isSelected = ref.read(onboardingProvider).gender == label;
    return BrutalCard(
      width: 92,
      height: 100,
      color: isSelected ? c.butter : c.surface,
      onTap: () {
        ref.read(onboardingProvider.notifier).setGenderAge(label, int.tryParse(_ageController.text) ?? 25);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 34, color: isSelected ? c.onPastel : c.ink),
          const SizedBox(height: 6),
          Text(label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: isSelected ? c.onPastel : c.ink)),
        ],
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
                Transform.scale(
                  scale: 1.1,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('km')),
                      ButtonSegment(value: false, label: Text('mi')),
                    ],
                    selected: {isKm},
                    onSelectionChanged: (set) => ref.read(isKmProvider.notifier).setKm(set.first),
                    showSelectedIcon: false,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                Text('Weight Units', style: theme.textTheme.labelSmall),
                const SizedBox(height: 8),
                Transform.scale(
                  scale: 1.1,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('kg')),
                      ButtonSegment(value: false, label: Text('lbs')),
                    ],
                    selected: {isKg},
                    onSelectionChanged: (set) => ref.read(isKgProvider.notifier).setKg(set.first),
                    showSelectedIcon: false,
                  ),
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
                      style: theme.textTheme.headlineSmall?.copyWith(color: context.stride.inkMuted),
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
                      style: theme.textTheme.headlineSmall?.copyWith(color: context.stride.inkMuted),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: Listenable.merge([_heightController, _weightController]),
          builder: (context, _) {
            final heightCm = double.tryParse(_heightController.text) ?? 0.0;
            var weight = double.tryParse(_weightController.text) ?? 0.0;
            
            if (!isKg) {
              weight = lbsToKg(weight);
            }
            
            double bmi = 0.0;
            if (heightCm > 0 && weight > 0) {
              final heightM = heightCm / 100.0;
              bmi = weight / (heightM * heightM);
            }
            
            final c = context.stride;
            String category = '';
            Color color = c.surface;
            if (bmi > 0) {
              if (bmi < 18.5) {
                category = 'Underweight';
                color = c.sky;
              } else if (bmi < 25) {
                category = 'Normal';
                color = c.sage;
              } else if (bmi < 30) {
                category = 'Overweight';
                color = c.butter;
              } else {
                category = 'Obese';
                color = c.blush;
              }
            }

            return bmi > 0 ? BrutalCard(
              color: color,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BODY MASS INDEX', style: theme.textTheme.labelSmall?.copyWith(color: c.onPastel)),
                      const SizedBox(height: 4),
                      Text(bmi.toStringAsFixed(1), style: theme.textTheme.displaySmall?.copyWith(color: c.onPastel)),
                    ],
                  ),
                  BrutalPill(text: category.toUpperCase(), color: c.surface),
                ],
              ),
            ).animate().fadeIn() : const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildMetricField(TextEditingController controller, String label, String unit, {bool isInt = false}) {
    final theme = Theme.of(context);
    return BrutalCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
          TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
            textAlign: TextAlign.center,
            style: theme.textTheme.displayLarge?.copyWith(fontSize: 26),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              suffixText: unit,
              suffixStyle: theme.textTheme.bodyMedium,
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
    final c = context.stride;
    // A selected option pops (scale overshoot) and its check spins in.
    return TweenAnimationBuilder<double>(
      key: ValueKey('$label-$isSelected'),
      tween: Tween(begin: isSelected ? 0.94 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: const ElasticOutCurve(0.6),
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: BrutalCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        color: isSelected ? c.butter : c.surface,
        onTap: () {
          onTap();
          setState(() {}); // options read the provider directly, so rebuild
        },
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isSelected ? c.onPastel : c.ink),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: Tween(begin: -0.25, end: 0.0).animate(anim),
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: Icon(
                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                key: ValueKey(isSelected),
                color: isSelected ? c.onPastel : c.ink.withValues(alpha: 0.35),
              ),
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BrutalPill(text: 'STEP $step OF $total', color: context.stride.sky),
                    const SizedBox(height: 12),
                    Text(title, style: theme.textTheme.headlineLarge),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Moop(size: 64, mood: step == total ? MoopMood.excited : MoopMood.idle),
            ],
          ).animate().fadeIn(duration: 350.ms),
          const SizedBox(height: 28),
          ...children.animate(interval: 100.ms).fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0),
        ],
      ),
    );
  }
}
