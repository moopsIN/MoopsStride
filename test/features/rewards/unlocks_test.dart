import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride/features/rewards/data/rewards_seen_store.dart';
import 'package:stride/features/rewards/domain/badges.dart';
import 'package:stride/features/rewards/domain/rewards_engine.dart';
import 'package:stride/features/tracking/models/activity_model.dart';

var _seq = 0;
ActivityModel run(DateTime start, double meters, {String? id}) => ActivityModel(
      id: id ?? 'u${_seq++}',
      type: 'run',
      startTime: start,
      endTime: start.add(const Duration(minutes: 30)),
      distanceMeters: meters,
      durationSeconds: 1800,
      avgPace: 6,
      caloriesEstimate: 100,
      routePoints: const [],
    );

final now = DateTime(2026, 10, 23, 18);
RewardsSnapshot snap(List<ActivityModel> runs) => RewardsEngine.compute(runs, now);

void main() {
  late RewardsSeenStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = RewardsSeenStore(await SharedPreferences.getInstance());
  });

  /// Simulates saving [newRun] on top of [history], the only path that can
  /// produce celebrations.
  Future<List<BadgeId>> save(List<ActivityModel> history, ActivityModel newRun) async {
    final u = await store.recordRun(snap(history), snap([...history, newRun]));
    return u.badges;
  }

  test('the very first run celebrates First stride, once', () async {
    final first = run(DateTime(2026, 10, 1, 9), 1500);
    expect(await save([], first), [BadgeId.firstStride]);
    // A later run doesn't re-celebrate it.
    expect(await save([first], run(DateTime(2026, 10, 3, 9), 1500)), isEmpty);
  });

  test('fresh device with synced history: nothing old is celebrated', () async {
    // Lots of history arrives by sync; nothing is "saved" here.
    final history = [for (var i = 0; i < 10; i++) run(DateTime(2026, 9, 1 + i, 9), 6000)];
    // The next local run only celebrates what it newly earns.
    final unlocked = await save(history, run(DateTime(2026, 9, 11, 9), 1000));
    expect(unlocked, isNot(contains(BadgeId.firstStride)));
    expect(unlocked, isNot(contains(BadgeId.run5k)));
    expect(unlocked, isNot(contains(BadgeId.streak7))); // already reached at day 7
  });

  test('exactly one celebration per newly earned badge, in catalogue order', () async {
    final unlocked = await save([], run(DateTime(2026, 10, 1, 6, 30), halfMarathonMeters));
    expect(unlocked, [
      BadgeId.firstStride,
      BadgeId.run5k,
      BadgeId.run10k,
      BadgeId.runHalf,
      BadgeId.total10,
      BadgeId.earlyBird,
    ]);
  });

  test('a badge lost by deleting a run and earned again is not re-celebrated', () async {
    final first = run(DateTime(2026, 10, 1, 9), 5000, id: 'five');
    expect(await save([], first), contains(BadgeId.run5k));
    // Run deleted: the 5K badge disappears from the snapshot...
    expect(snap([]).earned.containsKey(BadgeId.run5k), isFalse);
    // ...and a new 5K earns it back silently.
    expect(await save([], run(DateTime(2026, 10, 2, 9), 5000)), isNot(contains(BadgeId.run5k)));
  });

  test('undo-restoring a deleted run never celebrates (it is not a save)', () async {
    final five = run(DateTime(2026, 10, 1, 9), 5000);
    await save([], five);
    // Restore is just a recompute with the run back; no recordRun call, so
    // there is nothing to celebrate by construction. Saving afterwards
    // doesn't resurface it either.
    expect(await save([five], run(DateTime(2026, 10, 2, 9), 500)), isEmpty);
  });

  test('level-ups are celebrated once and listed first', () async {
    final u = await store.recordRun(snap([]), snap([run(DateTime(2026, 10, 1, 9), 10000)]));
    expect(u.newLevel, 2);
    expect(u.count, u.badges.length + 1);

    // Losing the level (delete) and regaining it doesn't celebrate again.
    final again = await store.recordRun(snap([]), snap([run(DateTime(2026, 10, 2, 9), 10000)]));
    expect(again.newLevel, isNull);
  });

  test('no unlocks when a run changes nothing', () async {
    final history = [run(DateTime(2026, 10, 1, 9), 1500)];
    await save([], history.first);
    final u = await store.recordRun(snap(history), snap([...history, run(DateTime(2026, 10, 1, 12), 100)]));
    expect(u.isEmpty, isTrue);
  });

  test('clear() forgets everything, e.g. after sign-out', () async {
    await save([], run(DateTime(2026, 10, 1, 9), 5000));
    expect(store.seenBadges, isNotEmpty);
    await store.clear();
    expect(store.seenBadges, isEmpty);
    expect(store.seenLevel, 1);
  });

  test('unknown badge names in storage are ignored', () async {
    SharedPreferences.setMockInitialValues({'rewards_seen_badges_v1': ['firstStride', 'retiredBadge']});
    final s = RewardsSeenStore(await SharedPreferences.getInstance());
    expect(s.seenBadges, {BadgeId.firstStride});
  });
}
