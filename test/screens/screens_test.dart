import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:stride/features/splash/splash_screen.dart';
import 'package:stride/features/tracking/presentation/tracking_screen.dart';
import 'package:stride/features/tracking/providers/tracking_provider.dart';

import '../helpers/harness.dart';

/// Every screen must render in light and dark at a small phone width without
/// layout overflow (overflows surface as test exceptions).
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
      // Let it route away so no timers are left pending.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
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
        await tester.pump(const Duration(seconds: 1));
        await screenshot(tester, 'home_${status.name}_$mode');
        expect(tester.takeException(), isNull);
        await disposeScreen(tester);
      });
    }
  }
}
