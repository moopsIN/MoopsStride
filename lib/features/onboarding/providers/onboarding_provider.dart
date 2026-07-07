import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/core/database/local_db.dart';

class OnboardingState {
  final String goal;
  final String experienceLevel;
  final String gender;
  final int age;
  final double height;
  final double weight;
  final String activityLevel;
  final bool isSaving;
  final bool hasError;

  OnboardingState({
    this.goal = '',
    this.experienceLevel = '',
    this.gender = '',
    this.age = 25,
    this.height = 0.0,
    this.weight = 0.0,
    this.activityLevel = '',
    this.isSaving = false,
    this.hasError = false,
  });

  OnboardingState copyWith({
    String? goal,
    String? experienceLevel,
    String? gender,
    int? age,
    double? height,
    double? weight,
    String? activityLevel,
    bool? isSaving,
    bool? hasError,
  }) {
    return OnboardingState(
      goal: goal ?? this.goal,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      gender: gender ?? this.gender,
      age: age ?? this.age,
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

  void setGenderAge(String gender, int age) {
    state = state.copyWith(gender: gender, age: age);
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
        'gender': state.gender,
        'age': state.age,
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
