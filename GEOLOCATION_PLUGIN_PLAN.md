# Custom Native Geolocation Plugin — Plan

## Context

Moops Stride's tracking screen needs GPS tracking to keep running when the app is backgrounded or the device is locked — the single most common real-world usage pattern for a walking/running tracker (phone locked, in a pocket or armband).

We currently use the `geolocator` package (`geolocator_android` 5.0.3, the latest published version). Its foreground-service mode (`AndroidSettings.foregroundNotificationConfig`) is required to keep location updates flowing in the background, but it has a confirmed, reproducible bug: the Android foreground service and its persistent notification start correctly, but `Position` updates from Google's `FusedLocationProviderClient` never reach the Dart side. This was verified on-device: native OS logs (`dumpsys location`, `dumpsys power`) showed Play Services continuously scanning for a location fix (wake-lock acquire/release cycles every ~5s) while zero callbacks arrived in Flutter. Removing the foreground-service config restores normal foreground-only tracking immediately, confirming the bug is isolated to that code path.

This is not specific to our setup — the plugin's GitHub repo has multiple open, longstanding issues describing the same failure class (e.g. "Location background service has not started correctly", "getPositionStream stops listening ... after a while of mobile screen off and device idle"). We're already on the latest version, so there's no version bump that fixes this.

**Decision:** rather than depend on a third-party plugin with an unresolved background-tracking bug (or pay for a commercial alternative like `flutter_background_geolocation`), we will write a small, purpose-built native location bridge ourselves — one Kotlin implementation for Android, one Swift implementation for iOS — exposed to Dart via a single platform channel pair. `geolocator` is dropped entirely from the location-streaming path. `permission_handler` (already a dependency, already used for `ACTIVITY_RECOGNITION`) continues to handle permission requesting/checking, since it works reliably today and rebuilding permission plumbing natively adds risk for no benefit.

Distance calculation (Haversine formula) moves to pure Dart — trivial, no native code needed, and removes another point of dependency on `geolocator`.

**Explicitly out of scope for this plan:** the pedometer/step-counting freeze noticed during testing is a separate, unrelated issue (Android hardware step-counter batching behavior) and will be investigated separately.

---

## Current architecture (for reference)

- [lib/features/tracking/providers/location_service.dart](lib/features/tracking/providers/location_service.dart) — wraps `geolocator`: `requestPermission()`, `requestBackgroundPermission()`, `getPositionStream()`, `getCurrentPosition()`, `calculateDistance()`.
- [lib/features/tracking/providers/tracking_provider.dart](lib/features/tracking/providers/tracking_provider.dart) — `TrackingNotifier.startTracking()` subscribes to `locService.getPositionStream()`, accumulates `routePoints`/`distanceMeters` in `TrackingState` on each `Position`.
- Android manifest already has `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`, and a `<service>` entry for `geolocator`'s own service class (to be replaced with our own).
- iOS `Info.plist` already has `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes: [location]`.
- `google-services`/Play Services location library (`play-services-location`) is already present transitively via `geolocator_android`'s own `build.gradle` — no new Gradle dependency needed once `geolocator_android` is removed, so we'll need to add it explicitly.

---

## Target Dart-facing API

A new `lib/features/tracking/providers/native_location_service.dart` replaces `location_service.dart` with the same shape `TrackingNotifier` already expects, so `tracking_provider.dart` changes minimally:

```dart
class NativeLocationService {
  Future<bool> requestPermission();       // uses permission_handler; foreground (When In Use) location
  Future<void> requestBackgroundPermission(); // uses permission_handler; background (Always) location, Android two-step
  Stream<LocationFix> getPositionStream(); // NEW: backed by MethodChannel+EventChannel, not geolocator
  Future<LocationFix?> getCurrentPosition();
  double calculateDistance(LatLng start, LatLng end); // Haversine, pure Dart, no native call
}

class LocationFix {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;
}
```

`TrackingNotifier` swaps `Position` (geolocator's type) for this new `LocationFix` — a mechanical rename across `tracking_provider.dart`, no logic changes needed there.

---

## Android implementation

**New Kotlin service**, e.g. `android/app/src/main/kotlin/in/moops/stride/location/StrideLocationService.kt`:
- Extends `Service`, holds a `FusedLocationProviderClient` (via `LocationServices.getFusedLocationProviderClient(context)`).
- `onStartCommand`: calls `startForeground(NOTIFICATION_ID, notification)` immediately (required within seconds on Android 8+/API 26+, or the OS kills the service) with a simple persistent notification ("Stride is tracking your activity").
  - The notification is built with `NotificationCompat.Builder.setContentIntent(...)` wrapping a `PendingIntent.getActivity(...)` targeting `MainActivity`, so tapping it brings the app to the foreground (standard pattern, matches user's decision above). Use `PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE` (required on API 23+).
- Registers a `LocationCallback` via `fusedLocationProviderClient.requestLocationUpdates(locationRequest, callback, Looper.getMainLooper())`, using `LocationRequest.Builder` (modern API, matches what `geolocator_android` itself uses — this part of Google's API is not the buggy part).
- On each `onLocationResult`, forwards `lat/lng/accuracy/timestamp` to Flutter via an `EventChannel.EventSink`.
- `onDestroy`: calls `fusedLocationProviderClient.removeLocationUpdates(callback)` and `stopForeground()`.

**New Kotlin plugin glue**, e.g. `android/app/src/main/kotlin/in/moops/stride/location/StrideLocationPlugin.kt`:
- Implements `FlutterPlugin`, registers a `MethodChannel` (`stride/location/methods`: `start`, `stop`, `isIgnoringBatteryOptimizations`, `requestIgnoreBatteryOptimizations`) and an `EventChannel` (`stride/location/events`: streams location fixes).
- `start` method binds/starts `StrideLocationService` (via `Context.startForegroundService` + `bindService`, same pattern `geolocator_android` uses, minus its bug).
- `isIgnoringBatteryOptimizations`/`requestIgnoreBatteryOptimizations` wrap `PowerManager.isIgnoringBatteryOptimizations(packageName)` and `Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))` respectively — called from Dart before/when starting a run (see Dart-side changes below).
- Registered in `MainActivity.kt`'s `configureFlutterEngine` (or via `GeneratedPluginRegistrant`-style manual registration, since this isn't a pub.dev plugin).

**Manifest changes**: replace the existing `<service android:name="com.baseflow.geolocator.GeolocatorLocationService" .../>` entry with one pointing at `in.moops.stride.location.StrideLocationService`, keep all existing permissions (`ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`), and add `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (needed for the battery-optimization prompt).

**Gradle**: add explicit `implementation("com.google.android.gms:play-services-location:21.3.0")` (or current stable) to `android/app/build.gradle.kts`, since we can no longer rely on `geolocator_android` pulling it in transitively.

---

## iOS implementation

**Status: written to spec, not verified on a physical device** — no iOS hardware available for testing in this pass. Ship behind the same interface as Android so it can be validated later without further Dart-side changes.

**New Swift bridge**, e.g. `ios/Runner/StrideLocationPlugin.swift`:
- Implements `FlutterPlugin`, `CLLocationManagerDelegate`.
- Holds a `CLLocationManager`, sets `allowsBackgroundLocationUpdates = true`, `pausesLocationUpdatesAutomatically = false`, `activityType = .fitness`, `desiredAccuracy = kCLLocationAccuracyBest`.
- `MethodChannel` handler for `start`/`stop`: calls `locationManager.startUpdatingLocation()` / `stopUpdatingLocation()`.
- `CLLocationManagerDelegate.locationManager(_:didUpdateLocations:)` forwards each `CLLocation` to Flutter via the same `EventChannel` pattern as Android (shared channel names, so Dart-side code is platform-agnostic).
- No custom service/lifecycle management needed — iOS handles background execution automatically once `UIBackgroundModes: location` (already set) + "Always" permission + `allowsBackgroundLocationUpdates` are in place. This is inherently simpler than Android.

**Registration**: register the plugin in `AppDelegate.swift`'s `didInitializeImplicitFlutterEngine` alongside `GeneratedPluginRegistrant.register(...)`.

**Info.plist**: no changes needed — `NSLocationAlwaysAndWhenInUseUsageDescription` and `UIBackgroundModes: [location]` are already present from the earlier background-tracking attempt.

---

## Dart-side changes

1. **New file** `lib/features/tracking/providers/native_location_service.dart` — the `NativeLocationService` class described above, wrapping the `MethodChannel`/`EventChannel` pair and exposing `Stream<LocationFix>`.
2. **Delete** `lib/features/tracking/providers/location_service.dart` and the `geolocator` dependency from `pubspec.yaml` (also drops `geolocator_android`/`geolocator_apple` transitive deps).
3. **Update** `lib/features/tracking/providers/tracking_provider.dart`:
   - `locationServiceProvider` now provides `NativeLocationService`.
   - `Position` → `LocationFix` in `startTracking()`'s stream listener and `_initCurrentLocation()`.
   - `locService.calculateDistance(...)` now calls a pure-Dart Haversine implementation (can live as a static method on `NativeLocationService` or a small top-level utility — implementation detail to decide at build time).
4. Re-enable the previously-disabled bits now that background tracking will actually work: restore `requestBackgroundPermission()` call in `startTracking()` and the `POST_NOTIFICATIONS` runtime request (currently commented out in `tracking_provider.dart` — see the `NOTE:` block there).
5. **Battery optimization prompt**: in `startTracking()` (Android only), before starting the location stream, call `NativeLocationService.isIgnoringBatteryOptimizations()`. If false, show a one-time explanatory dialog ("For reliable tracking while your phone is locked, allow Stride to run without battery restrictions") with a button that calls `requestIgnoreBatteryOptimizations()`. Track whether this has been shown before (e.g. a `SharedPreferences` flag) so it doesn't nag on every run — show once, or only re-show if the user later revokes the exemption.

---

## Testing plan

Same device-based verification approach already used in this session (adb logcat filtering, `dumpsys location`/`dumpsys power` to confirm native scanning, on-device walk tests), specifically checking:
- Foreground tracking still works exactly as it does today (regression check).
- Background tracking: start a run, lock the screen, walk for 60+ seconds, confirm distance/route keeps accumulating (check via logs and/or the final Run Summary after unlocking and stopping).
- Android: confirm the persistent notification appears and the service survives Doze mode for a few minutes (device-dependent; this Motorola device showed OEM-specific battery behavior earlier, worth re-checking here too).
- iOS: requires a real device (simulator doesn't reliably simulate background location) — flag this as a gap if only Android hardware is available for testing.

---

## Decisions

1. **iOS testing access** — Android-only real-device testing for now. The Swift bridge will be written to the same design as Android (same channel names/message shapes), but is unverified until a physical iOS device is available. Flag this clearly in the PR/commit and in a code comment on the Swift file.
2. **Android battery optimization** — prompt proactively. When a run starts (or on first launch), check `PowerManager.isIgnoringBatteryOptimizations(packageName)`; if false, show an explanatory in-app dialog before firing `Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)` (Android requires the explicit user-facing intent — it cannot be silently granted). Needs `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission added to the manifest. This directly addresses the empty `dumpsys deviceidle whitelist` we observed for this Motorola device during testing.
3. **Notification tap behavior** — tapping the persistent tracking notification brings the app to the foreground. Implemented via a `PendingIntent.getActivity(...)` targeting `MainActivity` (with `FLAG_UPDATE_CURRENT` and appropriate mutability flag for the target API level), attached to the notification via `NotificationCompat.Builder.setContentIntent(...)`.
