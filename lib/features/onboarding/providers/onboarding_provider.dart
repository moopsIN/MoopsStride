import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/core/database/local_db.dart';

class OnboardingState {
  final String goal;
  final String experienceLevel;
  final double height;
  final double weight;
  final String activityLevel;
  final bool isSaving;
  final bool hasError;

  OnboardingState({
    this.goal = '',
    this.experienceLevel = '',
    this.height = 0.0,
    this.weight = 0.0,
    this.activityLevel = '',
    this.isSaving = false,
    this.hasError = false,
  });

  OnboardingState copyWith({
    String? goal,
    String? experienceLevel,
    double? height,
    double? weight,
    String? activityLevel,
    bool? isSaving,
    bool? hasError,
  }) {
    return OnboardingState(
      goal: goal ?? this.goal,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      activityLevel: activityLevel ?? this.activityLevel,
      isSaving: isSaving ?? this.isSaving,
      hasError: hasError ?? this.hasError,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => OnboardingState();

  void setGoal(String goal) {
    state = state.copyWith(goal: goal);
  }

  void setExperienceLevel(String level) {
    state = state.copyWith(experienceLevel: level);
  }

  void setHeightWeight(double height, double weight) {
    state = state.copyWith(height: height, weight: weight);
  }

  void setActivityLevel(String level) {
    state = state.copyWith(activityLevel: level);
  }

  Future<bool> saveProfile() async {
    state = state.copyWith(isSaving: true, hasError: false);
    try {
      final db = await LocalDatabase.instance.database;
      await db.insert('user_profile', {
        'goal': state.goal,
        'experience_level': state.experienceLevel,
        'height': state.height,
        'weight': state.weight,
        'activity_level': state.activityLevel,
        'units_preference': 'km', // default
      });
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, hasError: true);
      return false;
    }
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, OnboardingState>(() {
  return OnboardingNotifier();
});
