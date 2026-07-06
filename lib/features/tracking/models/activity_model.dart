import 'dart:convert';
import 'package:latlong2/latlong.dart';

class ActivityModel {
  final String id;
  final String type; // 'run' or 'walk'
  final DateTime startTime;
  final DateTime endTime;
  final double distanceMeters;
  final int durationSeconds;
  final double avgPace;
  final double caloriesEstimate;
  final List<LatLng> routePoints;
  final int steps;
  final bool synced;

  ActivityModel({
    required this.id,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.avgPace,
    required this.caloriesEstimate,
    required this.routePoints,
    this.steps = 0,
    this.synced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'avg_pace': avgPace,
      'calories_estimate': caloriesEstimate,
      'route_polyline': jsonEncode(routePoints.map((p) => [p.latitude, p.longitude]).toList()),
      'steps': steps,
      'synced': synced ? 1 : 0,
    };
  }

  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    List<LatLng> parsedRoute = [];
    if (map['route_polyline'] != null && map['route_polyline'] is String) {
      try {
        final List<dynamic> decoded = jsonDecode(map['route_polyline']);
        parsedRoute = decoded.map((point) {
          final p = point as List<dynamic>;
          return LatLng(p[0] as double, p[1] as double);
        }).toList();
      } catch (e) {
        // Handle parsing error
      }
    }

    return ActivityModel(
      id: map['id'] as String,
      type: map['type'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int),
      distanceMeters: map['distance_meters'] as double,
      durationSeconds: map['duration_seconds'] as int,
      avgPace: map['avg_pace'] as double,
      caloriesEstimate: map['calories_estimate'] as double,
      routePoints: parsedRoute,
      steps: map['steps'] as int? ?? 0,
      synced: (map['synced'] as int) == 1,
    );
  }
}
