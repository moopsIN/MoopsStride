import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/tracking/models/activity_model.dart';

class ProgressState {
  final List<ActivityModel> activities;
  final bool isLoading;
  final int currentStreak;
  final ActivityModel? longestRun;
  final ActivityModel? fastest5k;

  ProgressState({
    this.activities = const [],
    this.isLoading = true,
    this.currentStreak = 0,
    this.longestRun,
    this.fastest5k,
  });

  ProgressState copyWith({
    List<ActivityModel>? activities,
    bool? isLoading,
    int? currentStreak,
    ActivityModel? longestRun,
    ActivityModel? fastest5k,
  }) {
    return ProgressState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      currentStreak: currentStreak ?? this.currentStreak,
      longestRun: longestRun ?? this.longestRun,
      fastest5k: fastest5k ?? this.fastest5k,
    );
  }
}

class ProgressNotifier extends Notifier<ProgressState> {
  @override
  ProgressState build() {
    Future.microtask(() => _loadActivities());
    return ProgressState();
  }

  Future<void> _loadActivities() async {
    state = state.copyWith(isLoading: true);
    final rawData = await LocalDatabase.instance.getActivities();
    final activities = rawData.map((e) => ActivityModel.fromMap(e)).toList();
    
    // Calculate Streak
    final streak = _calculateStreak(activities);
    
    // Calculate PRs
    ActivityModel? longest;
    ActivityModel? fastest5k;
    
    for (final a in activities) {
      if (longest == null || a.distanceMeters > longest.distanceMeters) {
        longest = a;
      }
      if (a.distanceMeters >= 5000) {
        if (fastest5k == null || a.avgPace < fastest5k.avgPace) {
          fastest5k = a;
        }
      }
    }

    state = state.copyWith(
      activities: activities,
      isLoading: false,
      currentStreak: streak,
      longestRun: longest,
      fastest5k: fastest5k,
    );
  }
  
  void refresh() {
    _loadActivities();
  }

  Future<void> deleteActivity(String id) async {
    await LocalDatabase.instance.deleteActivity(id);
    _loadActivities();
  }

  int _calculateStreak(List<ActivityModel> acts) {
    if (acts.isEmpty) return 0;
    
    // Sort by date descending
    final sorted = List<ActivityModel>.from(acts)..sort((a, b) => b.startTime.compareTo(a.startTime));
    
    // Get unique days (local time)
    final uniqueDays = <String>{};
    for (final a in sorted) {
      uniqueDays.add('${a.startTime.year}-${a.startTime.month}-${a.startTime.day}');
    }
    
    final days = uniqueDays.map((d) {
      final parts = d.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }).toList();
    
    if (days.isEmpty) return 0;
    
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month}-${yesterday.day}';
    
    int streak = 0;
    DateTime currentDateToMatch;
    
    if (uniqueDays.contains(todayStr)) {
      currentDateToMatch = DateTime(today.year, today.month, today.day);
    } else if (uniqueDays.contains(yesterdayStr)) {
      currentDateToMatch = DateTime(yesterday.year, yesterday.month, yesterday.day);
    } else {
      return 0; // No activity today or yesterday
    }
    
    for (final day in days) {
      if (day.isAtSameMomentAs(currentDateToMatch)) {
        streak++;
        currentDateToMatch = currentDateToMatch.subtract(const Duration(days: 1));
      } else {
        break; // gap found
      }
    }
    
    return streak;
  }
}

final progressProvider = NotifierProvider<ProgressNotifier, ProgressState>(() {
  return ProgressNotifier();
});
