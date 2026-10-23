import 'package:flutter_test/flutter_test.dart';
import 'package:stride/features/rewards/domain/badges.dart';
import 'package:stride/features/rewards/domain/rewards_engine.dart';
import 'package:stride/features/tracking/models/activity_model.dart';

var _seq = 0;
ActivityModel run(DateTime start, double meters, {String? id}) => ActivityModel(
      id: id ?? 'r${_seq++}',
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
RewardsSnapshot compute(List<ActivityModel> runs) => RewardsEngine.compute(runs, now);
Set<BadgeId> earnedIds(List<ActivityModel> runs) => compute(runs).earned.keys.toSet();

void main() {
  group('empty history', () {
    test('earns nothing, level 1, every badge locked', () {
      final s = compute([]);
      expect(s.earned, isEmpty);
      expect(s.xp, 0);
      expect(s.level, 1);
      expect(s.locked.length, badgeCatalogue.length);
    });
  });

  group('first stride', () {
    test('any saved run earns it, even a tiny one', () {
      expect(earnedIds([run(DateTime(2026, 10, 1, 9), 10)]), contains(BadgeId.firstStride));
    });

    test('is credited to the earliest run regardless of input order', () {
      final late = run(DateTime(2026, 10, 5, 9), 2000, id: 'late');
      final early = run(DateTime(2026, 10, 1, 9), 2000, id: 'early');
      expect(compute([late, early]).earned[BadgeId.firstStride]!.runId, 'early');
    });
  });

  group('single-run distance', () {
    test('exactly at the threshold counts', () {
      expect(earnedIds([run(DateTime(2026, 10, 1, 9), 5000)]), contains(BadgeId.run5k));
    });

    test('just below does not', () {
      expect(earnedIds([run(DateTime(2026, 10, 1, 9), 4999.9)]), isNot(contains(BadgeId.run5k)));
    });

    test('several short runs do not add up to a 5K', () {
      final runs = [for (var i = 0; i < 5; i++) run(DateTime(2026, 10, 1 + i, 9), 1500)];
      expect(earnedIds(runs), isNot(contains(BadgeId.run5k)));
    });

    test('a half marathon earns 5K, 10K and half at once', () {
      final ids = earnedIds([run(DateTime(2026, 10, 1, 9), halfMarathonMeters)]);
      expect(ids, containsAll([BadgeId.run5k, BadgeId.run10k, BadgeId.runHalf]));
    });
  });

  group('lifetime distance', () {
    test('accumulates across runs and credits the run that crossed it', () {
      final runs = [
        run(DateTime(2026, 10, 1, 9), 4000, id: 'a'),
        run(DateTime(2026, 10, 2, 9), 4000, id: 'b'),
        run(DateTime(2026, 10, 3, 9), 2000, id: 'c'),
      ];
      final s = compute(runs);
      expect(s.earned[BadgeId.total10]!.runId, 'c');
      expect(s.earned.containsKey(BadgeId.total50), isFalse);
    });

    test('just below 10 km total is locked, with a progress hint', () {
      final s = compute([run(DateTime(2026, 10, 1, 9), 9990)]);
      expect(s.earned.containsKey(BadgeId.total10), isFalse);
      final p = s.locked.firstWhere((b) => b.id == BadgeId.total10);
      expect(p.fraction, closeTo(0.999, 0.001));
      expect(p.hint, '9.9 / 10.0 km'); // rounded down: never looks complete while locked
    });
  });

  group('streaks', () {
    test('3 consecutive days earns Hat trick on the third day', () {
      final runs = [
        run(DateTime(2026, 10, 1, 9), 1000),
        run(DateTime(2026, 10, 2, 9), 1000),
        run(DateTime(2026, 10, 3, 9), 1000, id: 'third'),
      ];
      expect(compute(runs).earned[BadgeId.streak3]!.runId, 'third');
    });

    test('two runs on one day do not make a 2-day streak', () {
      final runs = [run(DateTime(2026, 10, 1, 7), 1000), run(DateTime(2026, 10, 1, 19), 1000), run(DateTime(2026, 10, 2, 9), 1000)];
      expect(earnedIds(runs), isNot(contains(BadgeId.streak3)));
    });

    test('a gap resets it', () {
      final runs = [run(DateTime(2026, 10, 1, 9), 1000), run(DateTime(2026, 10, 2, 9), 1000), run(DateTime(2026, 10, 4, 9), 1000)];
      expect(earnedIds(runs), isNot(contains(BadgeId.streak3)));
    });

    test('a historical streak stays earned after it ends', () {
      final runs = [for (var i = 0; i < 7; i++) run(DateTime(2026, 1, 1 + i, 9), 1000)];
      expect(earnedIds(runs), containsAll([BadgeId.streak3, BadgeId.streak7]));
    });

    test('runs late at night and early next morning are consecutive days', () {
      final runs = [
        run(DateTime(2026, 10, 1, 23, 50), 1000),
        run(DateTime(2026, 10, 2, 0, 10), 1000),
        run(DateTime(2026, 10, 3, 12), 1000),
      ];
      expect(earnedIds(runs), contains(BadgeId.streak3));
    });

    test('streaks across a DST change still count', () {
      final runs = [run(DateTime(2026, 3, 7, 9), 1000), run(DateTime(2026, 3, 8, 9), 1000), run(DateTime(2026, 3, 9, 9), 1000)];
      expect(earnedIds(runs), contains(BadgeId.streak3));
    });
  });

  group('time of day', () {
    test('06:59 is early bird; 07:00 is not', () {
      expect(earnedIds([run(DateTime(2026, 10, 1, 6, 59), 1000)]), contains(BadgeId.earlyBird));
      expect(earnedIds([run(DateTime(2026, 10, 1, 7, 0), 1000)]), isNot(contains(BadgeId.earlyBird)));
    });

    test('21:00 is night owl; 20:59 is not', () {
      expect(earnedIds([run(DateTime(2026, 10, 1, 21, 0), 1000)]), contains(BadgeId.nightOwl));
      expect(earnedIds([run(DateTime(2026, 10, 1, 20, 59), 1000)]), isNot(contains(BadgeId.nightOwl)));
    });

    test('00:30 counts as early bird, not night owl', () {
      final ids = earnedIds([run(DateTime(2026, 10, 1, 0, 30), 1000)]);
      expect(ids, contains(BadgeId.earlyBird));
      expect(ids, isNot(contains(BadgeId.nightOwl)));
    });

    test('runs under 1 km do not qualify', () {
      expect(earnedIds([run(DateTime(2026, 10, 1, 6), 999)]), isNot(contains(BadgeId.earlyBird)));
    });
  });

  group('weekend warrior', () {
    // 2026-10-24 is a Saturday.
    test('Saturday + Sunday of the same weekend', () {
      final runs = [run(DateTime(2026, 10, 24, 9), 1000), run(DateTime(2026, 10, 25, 9), 1000, id: 'sun')];
      expect(compute(runs).earned[BadgeId.weekendWarrior]!.runId, 'sun');
    });

    test('Sunday then the next Saturday is not one weekend', () {
      final runs = [run(DateTime(2026, 10, 18, 9), 1000), run(DateTime(2026, 10, 24, 9), 1000)];
      expect(earnedIds(runs), isNot(contains(BadgeId.weekendWarrior)));
    });

    test('both days need a qualifying 1 km run', () {
      final runs = [run(DateTime(2026, 10, 24, 9), 500), run(DateTime(2026, 10, 25, 9), 3000)];
      expect(earnedIds(runs), isNot(contains(BadgeId.weekendWarrior)));
    });
  });

  group('XP and levels', () {
    test('XP is 10 per whole km plus 5 per run', () {
      expect(Levels.xpForRun(run(DateTime(2026), 999)), 5);
      expect(Levels.xpForRun(run(DateTime(2026), 1000)), 15);
      expect(Levels.xpForRun(run(DateTime(2026), 5999)), 55);
    });

    test('level thresholds: 0, 50, 150, 300, 500', () {
      expect([for (var l = 1; l <= 5; l++) Levels.thresholdFor(l)], [0, 50, 150, 300, 500]);
    });

    test('exactly at a threshold levels up; one below does not', () {
      expect(Levels.levelFor(49), 1);
      expect(Levels.levelFor(50), 2);
      expect(Levels.levelFor(149), 2);
      expect(Levels.levelFor(150), 3);
    });

    test('level is capped', () {
      expect(Levels.levelFor(1 << 30), Levels.maxLevel);
      final s = compute([for (var i = 0; i < 400; i++) run(DateTime(2026, 1, 1).add(Duration(hours: i)), 50000)]);
      expect(s.level, Levels.maxLevel);
      expect(s.isMaxLevel, isTrue);
    });

    test('progress within the level is consistent', () {
      final s = compute([run(DateTime(2026, 10, 1, 9), 10000)]); // 105 XP → level 2 (50..150)
      expect(s.level, 2);
      expect(s.xpIntoLevel, 55);
      expect(s.xpForLevel, 100);
    });

    test('XP never decreases as runs are added', () {
      final runs = <ActivityModel>[];
      var last = -1;
      for (var i = 0; i < 60; i++) {
        runs.add(run(DateTime(2026, 1, 1 + i, 9), 500.0 + (i * 397) % 9000));
        final xp = compute(runs).xp;
        expect(xp, greaterThanOrEqualTo(last));
        last = xp;
      }
    });

    test('deleting a run lowers XP and can drop the level and badges', () {
      final big = run(DateTime(2026, 10, 1, 9), 21097.5, id: 'big');
      final small = run(DateTime(2026, 10, 2, 9), 1000);
      final withBig = compute([big, small]);
      final without = compute([small]);
      expect(without.xp, lessThan(withBig.xp));
      expect(without.level, lessThanOrEqualTo(withBig.level));
      expect(without.earned.containsKey(BadgeId.runHalf), isFalse);
    });

    test('Moop growth tiers follow level', () {
      expect([1, 4, 5, 9, 10, 19, 20, 50].map(Levels.growthFor).toList(), [0, 0, 1, 1, 2, 2, 3, 3]);
    });
  });

  group('robustness', () {
    test('duplicate runs (same id, e.g. after sync) count once', () {
      final r = run(DateTime(2026, 10, 1, 9), 3000, id: 'dup');
      final once = compute([r]);
      final twice = compute([r, r]);
      expect(twice.xp, once.xp);
      expect(twice.earned.keys, once.earned.keys);
    });

    test('units are irrelevant: everything is metres', () {
      // 5 miles is over 5 km but under 10 km.
      final ids = earnedIds([run(DateTime(2026, 10, 1, 9), 5 * 1609.344)]);
      expect(ids, contains(BadgeId.run5k));
      expect(ids, isNot(contains(BadgeId.run10k)));
    });

    test('locked badges keep catalogue order', () {
      final order = compute([]).locked.map((b) => b.id).toList();
      expect(order, BadgeId.values);
    });
  });
}
