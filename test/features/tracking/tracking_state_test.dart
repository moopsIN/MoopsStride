import 'package:flutter_test/flutter_test.dart';
import 'package:stride/features/tracking/providers/tracking_provider.dart';

void main() {
  group('TrackingState Logic Tests', () {
    test('Initial state has zeroed metrics', () {
      final state = TrackingState();
      
      expect(state.distanceMeters, 0.0);
      expect(state.durationSeconds, 0);
      expect(state.formattedDuration, '00:00');
      expect(state.formattedSpeed, '0.0');
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

    test('Speed formatting handles standard speeds', () {
      final state = TrackingState(
        speedKmH: 12.0,
      );
      
      expect(state.currentSpeed, 12.0);
      expect(state.formattedSpeed, '12.0');
    });

    test('Speed formatting handles decimal speeds', () {
      final state = TrackingState(
        speedKmH: 10.5,
      );
      
      expect(state.currentSpeed, 10.5);
      expect(state.formattedSpeed, '10.5');
    });
  });
}
