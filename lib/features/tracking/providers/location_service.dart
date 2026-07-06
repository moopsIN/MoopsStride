import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false; // Location services are disabled.
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false; // Permissions are denied
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false; // Permissions are permanently denied
    }

    return true;
  }

  /// Asks for "Always"/background access so tracking keeps running while
  /// the app is backgrounded or the device is locked. Must be called only
  /// after foreground access has already been granted (Android disallows
  /// requesting both at once). Only relevant when actively tracking, not
  /// for one-off lookups like centering the map — so this is intentionally
  /// separate from [requestPermission]. Denial isn't fatal: tracking simply
  /// pauses when the app leaves the foreground.
  Future<void> requestBackgroundPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) {
      await Geolocator.requestPermission();
    }
  }

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: _platformLocationSettings(),
    );
  }

  LocationSettings _platformLocationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Stride is tracking your activity',
          notificationText: 'Tap to return to your run or walk.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }

  Future<Position?> getCurrentPosition() async {
    if (await requestPermission()) {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    }
    return null;
  }

  double calculateDistance(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
