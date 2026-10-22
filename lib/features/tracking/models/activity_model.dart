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

  double get avgSpeedKmH {
    if (durationSeconds == 0) return 0.0;
    final hours = durationSeconds / 3600.0;
    return (distanceMeters / 1000.0) / hours;
  }

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

  /// Numbers are read as `num`: a whole double can come back as an int
  /// (e.g. after a Firestore round trip).
  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    List<LatLng> parsedRoute = [];
    if (map['route_polyline'] != null && map['route_polyline'] is String) {
      try {
        final List<dynamic> decoded = jsonDecode(map['route_polyline']);
        parsedRoute = decoded.map((point) {
          final p = point as List<dynamic>;
          return LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble());
        }).toList();
      } catch (e) {
        // Handle parsing error
      }
    }

    return ActivityModel(
      id: map['id'] as String,
      type: map['type'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch((map['start_time'] as num).toInt()),
      endTime: DateTime.fromMillisecondsSinceEpoch((map['end_time'] as num).toInt()),
      distanceMeters: (map['distance_meters'] as num).toDouble(),
      durationSeconds: (map['duration_seconds'] as num).toInt(),
      avgPace: (map['avg_pace'] as num).toDouble(),
      caloriesEstimate: (map['calories_estimate'] as num).toDouble(),
      routePoints: parsedRoute,
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      synced: map['synced'] == 1,
    );
  }
}
