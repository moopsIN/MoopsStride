import 'package:flutter/material.dart' hide Split;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/rewards/data/rewards_seen_store.dart';
import 'package:stride/features/rewards/data/run_rewards.dart';
import 'package:stride/features/rewards/domain/badges.dart';
import 'package:stride/features/rewards/domain/unlocks.dart';
import 'package:stride/features/rewards/presentation/celebration_sheet.dart';
import 'package:stride/features/tracking/models/activity_model.dart';
import 'package:stride/features/tracking/presentation/run_summary_screen.dart';

import '../../helpers/harness.dart';

ActivityModel run(String id, DateTime start, double meters) => ActivityModel(
      id: id,
      type: 'run',
      startTime: start,
      endTime: start.add(const Duration(minutes: 30)),
      distanceMeters: meters,
      durationSeconds: 1800,
      avgPace: 6,
      caloriesEstimate: 100,
      routePoints: const [],
    );

void main() {
  setUpAll(setUpScreenTests);

  group('saveRunAndCollectUnlocks', () {
    late RewardsSeenStore store;
    final now = DateTime(2026, 10, 23, 20);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = RewardsSeenStore(await SharedPreferences.getInstance());
      final db = await LocalDatabase.instance.database;
      await db.delete('activities');
    });

    Future<Unlocks> saveRun(ActivityModel r) => saveRunAndCollectUnlocks(
          run: r,
          save: () => LocalDatabase.instance.insertActivity(r.toMap()),
          store: store,
          now: now,
        );

    test('the first saved run unlocks First stride and is persisted', () async {
      final u = await saveRun(run('a', DateTime(2026, 10, 23, 9), 1200));
      expect(u.badges, [BadgeId.firstStride]);
      expect(await LocalDatabase.instance.getActivities(), hasLength(1));
    });

    test('runs already on the device (e.g. synced) count as history, not unlocks', () async {
      for (var i = 0; i < 3; i++) {
        await LocalDatabase.instance.insertActivity(run('h$i', DateTime(2026, 10, 18 + i, 9), 5000).toMap());
      }
      final u = await saveRun(run('new', DateTime(2026, 10, 23, 9), 1200));
      expect(u.badges, isNot(contains(BadgeId.firstStride)));
      expect(u.badges, isNot(contains(BadgeId.run5k)));
      expect(u.badges, isNot(contains(BadgeId.streak3)));
    });

    test('deleted (tombstoned) runs are not history', () async {
      await LocalDatabase.instance.insertActivity(run('gone', DateTime(2026, 10, 20, 9), 5000).toMap());
      await LocalDatabase.instance.deleteActivity('gone');
      final u = await saveRun(run('a', DateTime(2026, 10, 23, 9), 1200));
      expect(u.badges, contains(BadgeId.firstStride));
    });

    test('if the save fails, nothing is recorded or celebrated', () async {
      await expectLater(
        saveRunAndCollectUnlocks(
          run: run('x', DateTime(2026, 10, 23, 9), 1200),
          save: () async => throw StateError('disk full'),
          store: store,
          now: now,
        ),
        throwsStateError,
      );
      expect(store.seenBadges, isEmpty);
      // So the next successful save still celebrates First stride.
      expect((await saveRun(run('y', DateTime(2026, 10, 23, 10), 1200))).badges, contains(BadgeId.firstStride));
    });

    test('re-saving the same run id does not double count', () async {
      final r = run('same', DateTime(2026, 10, 23, 9), 1200);
      await saveRun(r);
      final again = await saveRun(r);
      expect(again.isEmpty, isTrue);
    });
  });

  group('celebration sheet', () {
    Future<void> open(WidgetTester tester, Unlocks unlocks, {bool dark = false}) async {
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showCelebration(context, unlocks),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        dark: dark,
        size: const Size(360, 740),
      );
      await tester.tap(find.text('open'));
      await settleFrames(tester, frames: 10);
    }

    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';

      testWidgets('single badge: shows it and closes on Nice! ($mode)', (tester) async {
        await open(tester, const Unlocks(badges: [BadgeId.run5k]), dark: dark);
        await screenshot(tester, 'celebrate_badge_$mode');
        expect(find.text('NEW BADGE'), findsOneWidget);
        expect(find.text('5K'), findsNWidgets(2)); // tile + headline, case kept
        expect(find.textContaining(' OF '), findsNothing);
        await tester.tap(find.text('Nice!'));
        await settleFrames(tester, frames: 10);
        expect(find.byType(CelebrationSheet), findsNothing);
        expect(tester.takeException(), isNull);
        await disposeScreen(tester);
      });

      testWidgets('level-up first, then badges in order ($mode)', (tester) async {
        await open(tester, const Unlocks(newLevel: 5, badges: [BadgeId.firstStride, BadgeId.earlyBird]), dark: dark);
        await screenshot(tester, 'celebrate_level_$mode');
        expect(find.text('LEVEL UP'), findsOneWidget);
        expect(find.text('level 5!'), findsOneWidget);
        expect(find.text('1 OF 3'), findsOneWidget);

        await tester.tap(find.text('Next'));
        await settleFrames(tester, frames: 5);
        expect(find.text('first stride'), findsOneWidget);
        expect(find.text('2 OF 3'), findsOneWidget);

        await tester.tap(find.text('Next'));
        await settleFrames(tester, frames: 5);
        expect(find.text('early bird'), findsOneWidget);
        expect(find.text('Nice!'), findsOneWidget);

        await tester.tap(find.text('Nice!'));
        await settleFrames(tester, frames: 10);
        expect(find.byType(CelebrationSheet), findsNothing);
        expect(tester.takeException(), isNull);
        await disposeScreen(tester);
      });
    }

    testWidgets('nothing to celebrate shows nothing', (tester) async {
      await open(tester, Unlocks.none);
      expect(find.byType(CelebrationSheet), findsNothing);
      await disposeScreen(tester);
    });

    testWidgets('run summary opens the celebration when given unlocks', (tester) async {
      await pumpScreen(
        tester,
        RunSummaryScreen(
          activity: run('s', DateTime(2026, 10, 23, 7), 5100),
          unlocks: const Unlocks(badges: [BadgeId.run5k]),
        ),
        size: const Size(360, 740),
      );
      await settleFrames(tester);
      expect(find.byType(CelebrationSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });

    testWidgets('run summary without unlocks does not', (tester) async {
      await pumpScreen(tester, RunSummaryScreen(activity: run('t', DateTime(2026, 10, 23, 7), 5100)),
          size: const Size(360, 740));
      await settleFrames(tester);
      expect(find.byType(CelebrationSheet), findsNothing);
      await disposeScreen(tester);
    });
  });
}
