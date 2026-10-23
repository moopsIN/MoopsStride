import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride/features/rewards/domain/badges.dart';
import 'package:stride/features/rewards/domain/rewards_engine.dart';
import 'package:stride/features/rewards/domain/unlocks.dart';

/// Per-device memory of which unlocks were already celebrated. This is the
/// only rewards state that's stored; everything else is derived from runs.
class RewardsSeenStore {
  static const _badgesKey = 'rewards_seen_badges_v1';
  static const _levelKey = 'rewards_seen_level_v1';

  final SharedPreferences prefs;
  RewardsSeenStore(this.prefs);

  Set<BadgeId> get seenBadges {
    final names = prefs.getStringList(_badgesKey) ?? const [];
    return {
      for (final n in names)
        for (final id in BadgeId.values)
          if (id.name == n) id,
    };
  }

  int get seenLevel => prefs.getInt(_levelKey) ?? 1;

  /// Returns what a just-saved run unlocked and remembers everything in
  /// both snapshots as seen, so history (including synced history) is never
  /// celebrated later.
  Future<Unlocks> recordRun(RewardsSnapshot before, RewardsSnapshot after) async {
    final seen = seenBadges;
    final unlocks = diffUnlocks(before: before, after: after, seenBadges: seen, seenLevel: seenLevel);
    final all = {...seen, ...before.earned.keys, ...after.earned.keys};
    await prefs.setStringList(_badgesKey, [for (final id in BadgeId.values) if (all.contains(id)) id.name]);
    await prefs.setInt(_levelKey, math.max(seenLevel, math.max(before.level, after.level)));
    return unlocks;
  }

  /// Forget everything; used when the account (and its runs) leave the device.
  Future<void> clear() async {
    await prefs.remove(_badgesKey);
    await prefs.remove(_levelKey);
  }
}
