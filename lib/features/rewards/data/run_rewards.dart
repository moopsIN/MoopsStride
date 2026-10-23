import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/rewards/data/rewards_seen_store.dart';
import 'package:stride/features/rewards/domain/rewards_engine.dart';
import 'package:stride/features/rewards/domain/unlocks.dart';
import 'package:stride/features/tracking/models/activity_model.dart';

/// Saves [run] via [save] and returns what it unlocked: the rewards for the
/// runs on this device before the save, versus after it. If [save] throws,
/// nothing is recorded or celebrated.
Future<Unlocks> saveRunAndCollectUnlocks({
  required ActivityModel run,
  required Future<void> Function() save,
  required RewardsSeenStore store,
  DateTime? now,
}) async {
  final clock = now ?? DateTime.now();
  final history = (await LocalDatabase.instance.getActivities())
      .map(ActivityModel.fromMap)
      .where((a) => a.id != run.id)
      .toList();
  final before = RewardsEngine.compute(history, clock);
  await save();
  final after = RewardsEngine.compute([...history, run], clock);
  return store.recordRun(before, after);
}
