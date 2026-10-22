import 'package:flutter/material.dart' hide Split;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/progress/presentation/progress_screen.dart';
import 'package:stride/features/splash/splash_screen.dart';
import 'package:stride/features/auth/presentation/auth_screen.dart';
import 'package:stride/features/onboarding/presentation/onboarding_screen.dart';
import 'package:stride/features/sync/presentation/sync_prompt_screen.dart';
import 'package:stride/features/tracking/presentation/tracking_screen.dart';
import 'package:stride/features/tracking/presentation/run_summary_screen.dart';
import 'package:stride/features/tracking/models/activity_model.dart';
import 'package:stride/features/tracking/models/split.dart';
import 'package:stride/features/tracking/providers/tracking_provider.dart';

import '../helpers/harness.dart';

/// Every screen must render in light and dark at a small phone width without
/// layout overflow (overflows surface as test exceptions).
final sampleRun = ActivityModel(
  id: 'sample',
  type: 'run',
  startTime: DateTime(2026, 10, 22, 7, 40),
  endTime: DateTime(2026, 10, 22, 8, 12),
  distanceMeters: 5230,
  durationSeconds: 1925,
  avgPace: 6.1,
  caloriesEstimate: 342,
  steps: 6104,
  routePoints: const [LatLng(22.7196, 75.8577), LatLng(22.7230, 75.8610), LatLng(22.7260, 75.8580)],
  splits: const [Split(1000, 371), Split(1000, 359), Split(1000, 380), Split(1000, 366), Split(1000, 372), Split(230, 77)],
);

void main() {
  setUpAll(setUpScreenTests);

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('splash ($mode)', (tester) async {
      await pumpScreen(tester, const SplashScreen(), dark: dark, size: const Size(360, 740));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await screenshot(tester, 'splash_running_$mode');
      await tester.pump(const Duration(milliseconds: 1500));
      await screenshot(tester, 'splash_end_$mode');
      expect(tester.takeException(), isNull);
      // Let it route away, then tear down so no timers are left pending.
      await settleFrames(tester);
      await disposeScreen(tester);
    });

    for (final status in [TrackingStatus.notStarted, TrackingStatus.active, TrackingStatus.paused]) {
      testWidgets('home ${status.name} ($mode)', (tester) async {
        await pumpScreen(
          tester,
          const TrackingScreen(),
          dark: dark,
          size: const Size(360, 740),
          tracking: TrackingState(
            status: status,
            currentLocation: const LatLng(22.72, 75.86),
            distanceMeters: status == TrackingStatus.notStarted ? 0 : 3420,
            durationSeconds: status == TrackingStatus.notStarted ? 0 : 1265,
            speedKmH: status == TrackingStatus.notStarted ? 0 : 9.7,
            currentSteps: status == TrackingStatus.notStarted ? 0 : 4210,
          ),
        );
        await settleFrames(tester);
        await screenshot(tester, 'home_${status.name}_$mode');
        expect(tester.takeException(), isNull);
        await disposeScreen(tester);
      });
    }

    testWidgets('run summary ($mode)', (tester) async {
      await pumpScreen(tester, RunSummaryScreen(activity: sampleRun), dark: dark, size: const Size(360, 740));
      await settleFrames(tester);
      await screenshot(tester, 'summary_$mode');
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    });

    for (final withRuns in [false, true]) {
      testWidgets('progress ${withRuns ? 'with runs' : 'empty'} ($mode)', (tester) async {
        // sqflite runs on an isolate, which fake async never lets finish.
        await tester.runAsync(() async {
          final db = await LocalDatabase.instance.database;
          await db.delete('activities');
          if (withRuns) {
            for (var i = 0; i < 6; i++) {
              final day = DateTime(2026, 10, 15 + i, 7);
              await LocalDatabase.instance.insertActivity(ActivityModel(
                id: 'p$i',
                type: 'run',
                startTime: day,
                endTime: day.add(const Duration(minutes: 30)),
                distanceMeters: 3000.0 + i * 700,
                durationSeconds: 1500 + i * 200,
                avgPace: 6,
                caloriesEstimate: 200,
                routePoints: const [],
              ).toMap());
            }
          }
        });
        await pumpScreen(tester, const ProgressScreen(), dark: dark, size: const Size(360, 740));
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
        await settleFrames(tester);
        await screenshot(tester, 'progress_${withRuns ? 'runs' : 'empty'}_$mode');
        expect(tester.takeException(), isNull);
        await disposeScreen(tester);
      });
    }

    final simple = <String, Widget Function()>{
      'auth': () => const AuthScreen(),
      'onboarding': () => const OnboardingScreen(),
      'sync_prompt': () => const SyncPromptScreen(),
      'sync_prompt_offline': () => const SyncPromptScreen(cloudUnreachable: true),
    };
    for (final entry in simple.entries) {
      testWidgets('${entry.key} ($mode)', (tester) async {
        await pumpScreen(tester, entry.value(), dark: dark, size: const Size(360, 740));
        await settleFrames(tester);
        await screenshot(tester, '${entry.key}_$mode');
        expect(tester.takeException(), isNull);
        await disposeScreen(tester);
      });
    }
  }
}
