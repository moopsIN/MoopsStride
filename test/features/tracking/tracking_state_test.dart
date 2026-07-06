import 'package:flutter_test/flutter_test.dart';
import 'package:stride/features/tracking/providers/tracking_provider.dart';

void main() {
  group('TrackingState Logic Tests', () {
    test('Initial state has zeroed metrics', () {
      final state = TrackingState();
      
      expect(state.distanceMeters, 0.0);
      expect(state.durationSeconds, 0);
      expect(state.formattedDuration, '00:00');
      expect(state.formattedPace, '--:--');
    });

    test('Distance formatting and km calculation', () {
      final state = TrackingState(distanceMeters: 2500); // 2.5 km
      
      expect(state.distanceKm, 2.5);
    });

    test('Formatted duration handles seconds, minutes, and hours', () {
      final state1 = TrackingState(durationSeconds: 45);
      expect(state1.formattedDuration, '00:45');
      
      final state2 = TrackingState(durationSeconds: 125); // 2 min 5 sec
      expect(state2.formattedDuration, '02:05');
      
      final state3 = TrackingState(durationSeconds: 3665); // 1 hr 1 min 5 sec
      expect(state3.formattedDuration, '01:01:05');
    });

    test('Pace calculation handles standard pacing', () {
      // 5km in 25 minutes = 5:00/km
      final state = TrackingState(
        distanceMeters: 5000, 
        durationSeconds: 25 * 60,
      );
      
      expect(state.currentPace, 5.0);
      expect(state.formattedPace, '5:00');
    });

    test('Pace calculation handles complex pacing', () {
      // 5km in 27 minutes 30 seconds = 5:30/km
      final state = TrackingState(
        distanceMeters: 5000, 
        durationSeconds: (27 * 60) + 30,
      );
      
      expect(state.currentPace, 5.5);
      expect(state.formattedPace, '5:30');
    });
  });
}
