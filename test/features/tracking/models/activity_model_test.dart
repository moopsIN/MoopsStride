import 'package:flutter_test/flutter_test.dart';
import 'package:stride/features/tracking/models/activity_model.dart';

void main() {
  test('fromMap accepts ints where doubles are expected', () {
    final activity = ActivityModel.fromMap({
      'id': 'a',
      'type': 'run',
      'start_time': 1700000000000,
      'end_time': 1700000600000,
      'distance_meters': 1000,
      'duration_seconds': 600,
      'avg_pace': 6,
      'calories_estimate': 50,
      'route_polyline': '[[12, 77], [12.5, 77.25]]',
      'synced': 1,
    });

    expect(activity.distanceMeters, 1000.0);
    expect(activity.avgPace, 6.0);
    expect(activity.routePoints.length, 2);
    expect(activity.routePoints.first.latitude, 12.0);
    expect(activity.synced, true);
  });
}
