import 'dart:math' as math;

import 'package:stride/features/rewards/domain/badges.dart';
import 'package:stride/features/rewards/domain/rewards_engine.dart';

/// What to celebrate after a run is saved: a level-up (shown first) and any
/// newly earned badges, in catalogue order.
class Unlocks {
  final int? newLevel;
  final List<BadgeId> badges;

  const Unlocks({this.newLevel, this.badges = const []});

  static const none = Unlocks();

  bool get isEmpty => newLevel == null && badges.isEmpty;
  int get count => badges.length + (newLevel == null ? 0 : 1);
}

/// Celebrations come only from the difference a saved run makes, never
/// from history arriving by sync or a restored run. [seenBadges] and
/// [seenLevel] stop the same unlock being celebrated twice (e.g. a badge
/// lost by deleting a run and then earned again).
Unlocks diffUnlocks({
  required RewardsSnapshot before,
  required RewardsSnapshot after,
  required Set<BadgeId> seenBadges,
  required int seenLevel,
}) {
  final badges = [
    for (final id in BadgeId.values)
      if (after.earned.containsKey(id) && !before.earned.containsKey(id) && !seenBadges.contains(id)) id,
  ];
  final levelUp = after.level > before.level && after.level > math.max(seenLevel, before.level);
  return Unlocks(newLevel: levelUp ? after.level : null, badges: badges);
}
