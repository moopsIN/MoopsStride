import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/core/providers/preferences_provider.dart';
import 'package:stride/features/progress/providers/progress_provider.dart';
import 'package:stride/features/rewards/data/rewards_seen_store.dart';
import 'package:stride/features/rewards/domain/rewards_engine.dart';

/// Rewards for the runs currently on this device (tombstoned runs are
/// already excluded by the progress provider). Recomputed whenever the run
/// list changes; cheap enough for thousands of runs.
final rewardsProvider = Provider<RewardsSnapshot>((ref) {
  final runs = ref.watch(progressProvider.select((s) => s.activities));
  return RewardsEngine.compute(runs, DateTime.now());
});

final rewardsSeenStoreProvider = Provider<RewardsSeenStore>((ref) {
  return RewardsSeenStore(ref.watch(sharedPreferencesProvider));
});
