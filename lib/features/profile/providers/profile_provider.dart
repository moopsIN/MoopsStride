import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/core/database/local_db.dart';

class ProfileState {
  final String goal;
  final String experienceLevel;
  final double height;
  final double weight;
  final String activityLevel;
  final bool isLoading;
  final bool isSaving;
  final bool hasError;

  ProfileState({
    this.goal = '',
    this.experienceLevel = '',
    this.height = 170.0,
    this.weight = 70.0,
    this.activityLevel = '',
    this.isLoading = true,
    this.isSaving = false,
    this.hasError = false,
  });

  ProfileState copyWith({
    String? goal,
    String? experienceLevel,
    double? height,
    double? weight,
    String? activityLevel,
    bool? isLoading,
    bool? isSaving,
    bool? hasError,
  }) {
    return ProfileState(
      goal: goal ?? this.goal,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      activityLevel: activityLevel ?? this.activityLevel,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      hasError: hasError ?? this.hasError,
    );
  }
}

class ProfileNotifier extends AsyncNotifier<ProfileState> {
  @override
  Future<ProfileState> build() async {
    return _loadProfile();
  }

  Future<ProfileState> _loadProfile() async {
    final data = await LocalDatabase.instance.getUserProfile();
    if (data != null) {
      return ProfileState(
        goal: data['goal'] as String? ?? '',
        experienceLevel: data['experience_level'] as String? ?? '',
        height: (data['height'] as num?)?.toDouble() ?? 170.0,
        weight: (data['weight'] as num?)?.toDouble() ?? 70.0,
        activityLevel: data['activity_level'] as String? ?? '',
        isLoading: false,
      );
    }
    return ProfileState(isLoading: false);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadProfile());
  }

  Future<bool> updateProfile({
    required String goal,
    required String experienceLevel,
    required double height,
    required double weight,
    required String activityLevel,
  }) async {
    final currentState = state.value;
    if (currentState == null) return false;

    state = AsyncData(currentState.copyWith(isSaving: true, hasError: false));

    try {
      await LocalDatabase.instance.updateUserProfile({
        'goal': goal,
        'experience_level': experienceLevel,
        'height': height,
        'weight': weight,
        'activity_level': activityLevel,
      });

      state = AsyncData(currentState.copyWith(
        goal: goal,
        experienceLevel: experienceLevel,
        height: height,
        weight: weight,
        activityLevel: activityLevel,
        isSaving: false,
      ));
      return true;
    } catch (e) {
      state = AsyncData(currentState.copyWith(isSaving: false, hasError: true));
      return false;
    }
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, ProfileState>(() {
  return ProfileNotifier();
});
