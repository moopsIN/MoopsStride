import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationFix {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;

  LocationFix({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
  });

  factory LocationFix.fromMap(Map<dynamic, dynamic> map) {
    return LocationFix(
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      accuracy: map['accuracy'] as double?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class NativeLocationService {
  static const MethodChannel _methodChannel = MethodChannel('stride/location/methods');
  static const EventChannel _eventChannel = EventChannel('stride/location/events');

  Future<bool> requestPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  Future<void> requestBackgroundPermission() async {
    final status = await Permission.locationAlways.status;
    if (!status.isGranted) {
      await Permission.locationAlways.request();
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? true;
    } catch (e) {
      return true;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _methodChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      // Ignore
    }
  }

  Future<bool> startService() async {
    try {
      await _methodChannel.invokeMethod('start');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> stopService() async {
    try {
      await _methodChannel.invokeMethod('stop');
    } catch (e) {
      // Already stopped/never started — nothing to clean up.
    }
  }

  Stream<LocationFix> getPositionStream() {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return LocationFix.fromMap(event as Map<dynamic, dynamic>);
    });
  }

  Future<LocationFix?> getCurrentPosition() async {
    try {
      final map = await _methodChannel.invokeMethod('getCurrentPosition');
      if (map != null) {
        return LocationFix.fromMap(map as Map<dynamic, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Haversine formula to calculate distance in meters between two coordinates.
  double calculateDistance(LatLng start, LatLng end) {
    const double R = 6371000; // Earth's radius in meters
    final double phi1 = start.latitude * math.pi / 180;
    final double phi2 = end.latitude * math.pi / 180;
    final double deltaPhi = (end.latitude - start.latitude) * math.pi / 180;
    final double deltaLambda = (end.longitude - start.longitude) * math.pi / 180;

    final double a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) * math.cos(phi2) *
        math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c;
  }
}

final locationServiceProvider = Provider<NativeLocationService>((ref) {
  return NativeLocationService();
});
