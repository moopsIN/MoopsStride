import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/sync/providers/sync_engine.dart';
import 'package:stride/features/auth/providers/auth_provider.dart';
import 'package:stride/features/rewards/domain/streaks.dart';
import 'package:stride/features/tracking/models/activity_model.dart';

class ProgressState {
  final List<ActivityModel> activities;
  final bool isLoading;
  final int currentStreak;
  final ActivityModel? longestRun;
  final ActivityModel? fastest5k;
  final double weekDistanceMeters;
  final int weekRuns;

  ProgressState({
    this.activities = const [],
    this.isLoading = true,
    this.currentStreak = 0,
    this.longestRun,
    this.fastest5k,
    this.weekDistanceMeters = 0,
    this.weekRuns = 0,
  });

  ProgressState copyWith({
    List<ActivityModel>? activities,
    bool? isLoading,
    int? currentStreak,
    ActivityModel? longestRun,
    ActivityModel? fastest5k,
    double? weekDistanceMeters,
    int? weekRuns,
  }) {
    return ProgressState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      currentStreak: currentStreak ?? this.currentStreak,
      longestRun: longestRun ?? this.longestRun,
      fastest5k: fastest5k ?? this.fastest5k,
      weekDistanceMeters: weekDistanceMeters ?? this.weekDistanceMeters,
      weekRuns: weekRuns ?? this.weekRuns,
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
    // Invalidated mid-load (e.g. sign-out): the result belongs to nobody.
    if (!ref.mounted) return;
    final activities = rawData.map((e) => ActivityModel.fromMap(e)).toList();
    
    // Calculate Streak
    final streak = currentStreak(activities.map((a) => a.startTime), DateTime.now());
    
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

    // Week runs Monday to Sunday, local time.
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final thisWeek = activities.where((a) => !a.startTime.isBefore(weekStart));

    state = state.copyWith(
      activities: activities,
      weekDistanceMeters: thisWeek.fold<double>(0, (sum, a) => sum + a.distanceMeters),
      weekRuns: thisWeek.length,
      isLoading: false,
      currentStreak: streak,
      longestRun: longest,
      fastest5k: fastest5k,
    );
  }
  
  void refresh() {
    _loadActivities();
  }

  /// Hides the run immediately; call [commitDeletes] once undo is no longer
  /// offered.
  Future<void> deleteActivity(String id) async {
    await LocalDatabase.instance.deleteActivity(id);
    await _loadActivities();
  }

  Future<bool> undoDelete(String id) async {
    final restored = await LocalDatabase.instance.restoreActivity(id);
    await _loadActivities();
    return restored;
  }

  /// Propagates deletes so runs don't come back from the cloud; guests have
  /// nothing to propagate, so their tombstones are simply removed.
  Future<void> commitDeletes() async {
    if (ref.read(authProvider) == null) {
      await LocalDatabase.instance.purgeTombstones();
    } else {
      await ref.read(syncEngineProvider).syncUnsyncedActivities();
    }
  }

}

final progressProvider = NotifierProvider<ProgressNotifier, ProgressState>(() {
  return ProgressNotifier();
});
