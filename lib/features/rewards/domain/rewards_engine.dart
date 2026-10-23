import 'dart:math' as math;

import 'package:stride/features/rewards/domain/badges.dart';
import 'package:stride/features/rewards/domain/streaks.dart';
import 'package:stride/features/tracking/models/activity_model.dart';

/// Everything earned so far, derived purely from run history. Nothing here
/// is stored: deleting or syncing runs simply produces a new snapshot.
class RewardsSnapshot {
  /// Earned badges with the run that earned them.
  final Map<BadgeId, EarnedBadge> earned;
  final int xp;
  final int level;
  /// XP gained since reaching [level], and the size of the current level.
  final int xpIntoLevel;
  final int xpForLevel;
  /// Locked badges with progress hints, in catalogue order.
  final List<BadgeProgress> locked;

  const RewardsSnapshot({
    required this.earned,
    required this.xp,
    required this.level,
    required this.xpIntoLevel,
    required this.xpForLevel,
    required this.locked,
  });

  bool get isMaxLevel => level >= Levels.maxLevel;

  /// How grown-up Moop looks: 0 sprout, 1 bushy, 2 flower, 3 crown.
  int get moopGrowth => Levels.growthFor(level);
}

class EarnedBadge {
  final BadgeId id;
  final String runId;
  final DateTime earnedAt;
  const EarnedBadge(this.id, this.runId, this.earnedAt);
}

class BadgeProgress {
  final BadgeId id;
  /// 0..1, or null where progress isn't meaningful (time-of-day, weekend).
  final double? fraction;
  final String hint;
  const BadgeProgress(this.id, this.fraction, this.hint);
}

/// XP and levels. Level L (1-based) is reached at 25·L·(L−1) XP, so each
/// level needs 50 XP more than the last: 0, 50, 150, 300, 500, …
abstract final class Levels {
  static const int maxLevel = 50;

  static int xpForRun(ActivityModel run) => 10 * (run.distanceMeters ~/ 1000) + 5;

  static int thresholdFor(int level) => 25 * level * (level - 1);

  static int levelFor(int xp) {
    var level = 1;
    while (level < maxLevel && xp >= thresholdFor(level + 1)) {
      level++;
    }
    return level;
  }

  static int growthFor(int level) {
    if (level >= 20) return 3;
    if (level >= 10) return 2;
    if (level >= 5) return 1;
    return 0;
  }
}

abstract final class RewardsEngine {
  /// Computes rewards from [runs] (any order; duplicates by id are ignored).
  /// [now] only affects hints for the current streak.
  static RewardsSnapshot compute(Iterable<ActivityModel> runs, DateTime now) {
    final byId = <String, ActivityModel>{for (final r in runs) r.id: r};
    final ordered = byId.values.toList()
      ..sort((a, b) {
        final t = a.startTime.compareTo(b.startTime);
        return t != 0 ? t : a.id.compareTo(b.id);
      });

    final earned = <BadgeId, EarnedBadge>{};
    void earn(BadgeId id, ActivityModel run) =>
        earned.putIfAbsent(id, () => EarnedBadge(id, run.id, run.startTime));

    var total = 0.0;
    var best = 0.0;
    var xp = 0;
    // Consecutive-day run length ending on each day seen so far. Runs are
    // processed in time order, so a new day is never before an older one.
    final streakEndingOn = <DateTime, int>{};
    final qualifyingDays = <DateTime>{};

    for (final run in ordered) {
      final meters = run.distanceMeters;
      total += meters;
      best = math.max(best, meters);
      xp += Levels.xpForRun(run);

      final day = localDay(run.startTime);
      final streak = streakEndingOn[day] ?? (streakEndingOn[addDays(day, -1)] ?? 0) + 1;
      streakEndingOn[day] = streak;

      final qualifies = meters >= qualifyingRunMeters;
      if (qualifies) qualifyingDays.add(day);

      for (final def in badgeCatalogue) {
        final hit = switch (def.kind) {
          BadgeKind.firstRun => true,
          BadgeKind.singleRun => meters >= def.target,
          BadgeKind.lifetime => total >= def.target,
          BadgeKind.streak => streak >= def.target,
          BadgeKind.timeOfDay => qualifies &&
              (def.id == BadgeId.earlyBird ? run.startTime.hour < 7 : run.startTime.hour >= 21),
          // Runs arrive in time order, so the Sunday run completes the pair.
          BadgeKind.weekend => qualifies &&
              day.weekday == DateTime.sunday &&
              qualifyingDays.contains(addDays(day, -1)),
        };
        if (hit) earn(def.id, run);
      }
    }

    final current = currentStreak(ordered.map((r) => r.startTime), now);
    final locked = [
      for (final def in badgeCatalogue)
        if (!earned.containsKey(def.id)) _progress(def, best: best, total: total, streak: current),
    ];

    final level = Levels.levelFor(xp);
    final floor = Levels.thresholdFor(level);
    final ceiling = level >= Levels.maxLevel ? floor : Levels.thresholdFor(level + 1);
    return RewardsSnapshot(
      earned: earned,
      xp: xp,
      level: level,
      xpIntoLevel: xp - floor,
      xpForLevel: ceiling - floor,
      locked: locked,
    );
  }

  static BadgeProgress _progress(BadgeDef def,
      {required double best, required double total, required int streak}) {
    // Round progress down so a locked badge never reads "10.0 / 10.0 km".
    String km(double m) => ((m / 100).floor() / 10).toStringAsFixed(1);
    switch (def.kind) {
      case BadgeKind.firstRun:
        return BadgeProgress(def.id, 0, 'Finish any run');
      case BadgeKind.singleRun:
        return BadgeProgress(def.id, (best / def.target).clamp(0, 1), 'Best run ${km(best)} / ${km(def.target)} km');
      case BadgeKind.lifetime:
        return BadgeProgress(def.id, (total / def.target).clamp(0, 1), '${km(total)} / ${km(def.target)} km');
      case BadgeKind.streak:
        final target = def.target.toInt();
        return BadgeProgress(def.id, (streak / target).clamp(0, 1), 'Current streak $streak / $target days');
      case BadgeKind.timeOfDay:
        return BadgeProgress(def.id, null, def.id == BadgeId.earlyBird ? 'Start before 7 am' : 'Start after 9 pm');
      case BadgeKind.weekend:
        return BadgeProgress(def.id, null, 'Run Saturday and Sunday');
    }
  }
}
