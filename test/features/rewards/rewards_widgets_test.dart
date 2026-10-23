import 'package:flutter/material.dart' hide Split;
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/core/widgets/moop.dart';
import 'package:stride/features/rewards/domain/badges.dart';
import 'package:stride/features/rewards/domain/rewards_engine.dart';
import 'package:stride/features/rewards/presentation/badges_screen.dart';
import 'package:stride/features/rewards/presentation/rewards_widgets.dart';
import 'package:stride/features/tracking/models/activity_model.dart';
import 'package:stride/theme/app_theme.dart';

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

Widget themed(Widget child, {bool dark = false}) => MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  setUpAll(setUpScreenTests);

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('earned badge tile shows its title and no lock ($mode)', (tester) async {
      await tester.pumpWidget(themed(const SizedBox(width: 110, child: BadgeTile(id: BadgeId.run5k, earned: true)), dark: dark));
      expect(find.text('5K'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
    });

    testWidgets('locked badge tile shows a lock and progress ($mode)', (tester) async {
      await tester.pumpWidget(
          themed(const SizedBox(width: 110, child: BadgeTile(id: BadgeId.total50, earned: false, progress: 0.4)), dark: dark));
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.byType(BrutalProgressBar), findsOneWidget);
    });

    testWidgets('level card shows level, XP to next and grown Moop ($mode)', (tester) async {
      // 25 runs of 10 km = 25 × 105 = 2625 XP → level 10 (2250..2750): flower Moop.
      final rewards = RewardsEngine.compute(
        [for (var i = 0; i < 25; i++) run('l$i', DateTime(2026, 1, 1 + i, 9), 10000)],
        DateTime(2026, 2, 1),
      );
      await tester.pumpWidget(themed(SizedBox(width: 340, child: LevelCard(rewards: rewards)), dark: dark));
      expect(find.text('level 10'), findsOneWidget);
      expect(find.text('375 / 500 XP TO LEVEL 11'), findsOneWidget);
      expect(tester.widget<Moop>(find.byType(Moop)).growth, 2);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('level card at max level ($mode)', (tester) async {
      final rewards = RewardsEngine.compute(
        [for (var i = 0; i < 400; i++) run('m$i', DateTime(2026, 1, 1).add(Duration(hours: i)), 50000)],
        DateTime(2026, 3, 1),
      );
      await tester.pumpWidget(themed(SizedBox(width: 340, child: LevelCard(rewards: rewards)), dark: dark));
      expect(find.textContaining('MAX LEVEL'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    for (final withRuns in [false, true]) {
      testWidgets('badges screen ${withRuns ? 'with runs' : 'empty'} ($mode)', (tester) async {
        await tester.runAsync(() async {
          final db = await LocalDatabase.instance.database;
          await db.delete('activities');
          if (withRuns) {
            for (var i = 0; i < 4; i++) {
              await LocalDatabase.instance.insertActivity(run('b$i', DateTime(2026, 10, 18 + i, 6, 30), 5200).toMap());
            }
          }
        });
        await pumpScreen(tester, const BadgesScreen(), dark: dark, size: const Size(360, 740));
        await settleFrames(tester);
        await screenshot(tester, 'badges_${withRuns ? 'runs' : 'empty'}_$mode');
        expect(tester.takeException(), isNull);
        if (withRuns) {
          expect(find.textContaining('EARNED · '), findsOneWidget);
          expect(find.text('Hat trick'), findsOneWidget);
        } else {
          expect(find.text('Finish a run to earn your first badge.'), findsOneWidget);
        }

        // Tapping a badge opens its detail sheet.
        await tester.tap(find.text('First stride').first);
        await settleFrames(tester);
        expect(find.text('first stride'), findsOneWidget);
        await disposeScreen(tester);
      });
    }
  }
}
