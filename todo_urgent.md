# URGENT: Background GPS Tracking — Phased Implementation Plan

**Audience note:** this doc is written so a fresh agent (no prior context on this repo/session) can pick up the work directly. It restates the full history so nothing has to be re-discovered. The detailed technical design lives in [GEOLOCATION_PLUGIN_PLAN.md](GEOLOCATION_PLUGIN_PLAN.md) — read that first, this file is the execution checklist plus "where we stand" summary.

---

## Where we stand right now (current repo state)

The app currently uses the `geolocator` package (`geolocator_android` 5.0.3, the latest published version as of writing) for GPS tracking. **Foreground tracking works correctly today** — distance, pace, and route all update live while the app is in the foreground. This was verified on a physical Android device (Motorola edge 50 fusion, Android 16 / API 36).

**Background/locked-screen tracking does NOT work, and is currently disabled on purpose.** Here's exactly what was tried and what was found:

1. We enabled `geolocator`'s `AndroidSettings.foregroundNotificationConfig`, which is supposed to start an Android foreground service + persistent notification and keep GPS updates flowing while the app is backgrounded/the screen is locked.
2. This **partially worked**: the foreground service started correctly, the persistent notification appeared (confirmed via `adb shell dumpsys` and logcat: `Notification(channel=geolocator_channel_01 ... flags=ONGOING_EVENT|NO_CLEAR|FOREGROUND_SERVICE)`).
3. **But no `Position` updates ever reached Dart.** We proved this two ways:
   - Added temporary `debugPrint` logging directly inside the `getPositionStream().listen(...)` callback — zero position events logged over multiple minutes of walking outdoors, even though a step-counter stream (separate feature) proved logging/rebuilds were working fine.
   - Ran `adb shell dumpsys location` and `adb shell dumpsys power` **while a run was active** — these showed Google Play Services **continuously scanning for a location fix** (`NetworkLocationScanner`/`NetworkLocationLocator` wake-lock acquire/release cycles every ~5 seconds, sustained for over a minute), proving the OS/GPS/Play-Services side was actively working — but the plugin's Dart-facing callback never fired.
4. We removed `foregroundNotificationConfig` (kept everything else the same) and **immediately** confirmed position events started arriving again on the very next run (same device, same code, only that one config removed). This isolates the bug precisely to `geolocator_android`'s foreground-service delivery code path (specifically `GeolocatorLocationService.startLocationService()` → `StreamHandlerImpl.onListen()` in the plugin's Kotlin source, for anyone who wants to inspect it in `~/.pub-cache/hosted/pub.dev/geolocator_android-5.0.3/`).
5. This is not unique to our setup — `geolocator`'s GitHub repo (`Baseflow/flutter-geolocator`) has multiple **open, longstanding, unresolved issues** describing this exact failure class, e.g. issue #1739 "Location background service has not started correctly" and #1023 "getPositionStream stops listening to position updates after a while of mobile screen off and device idle". We are already on the latest published `geolocator_android` version (5.0.3, released 2026-06-12), so there is no version bump that fixes this.
6. We also checked commercial/free alternatives:
   - `flutter_background_geolocation` (Transistor Soft) — most mature option, but **requires a paid license for production builds** (free only for dev/testing).
   - `background_locator_2` — free/MIT, but **unmaintained since March 2023**, low download volume, risky to depend on for a showcase app.
7. **Decision made:** build our own minimal native location bridge (Kotlin for Android, Swift for iOS) instead of depending on a third-party plugin for the background-tracking piece. Full rationale and technical design is in [GEOLOCATION_PLUGIN_PLAN.md](GEOLOCATION_PLUGIN_PLAN.md).

### Residual state left in the repo from these experiments (important — do not be confused by this)

- [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) still declares: `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS` permissions, **and a now-dead `<service android:name="com.baseflow.geolocator.GeolocatorLocationService" .../>` entry** — this service is never actually started because `foregroundNotificationConfig` is no longer passed anywhere, but the manifest entry was never removed. It should be replaced (not just deleted) once our own service exists, per the new plan.
- [ios/Runner/Info.plist](ios/Runner/Info.plist) still has `NSLocationAlwaysAndWhenInUseUsageDescription` and `UIBackgroundModes: [location]` — these are still correct/needed for the new iOS implementation too, no change needed there.
- [lib/features/tracking/providers/location_service.dart](lib/features/tracking/providers/location_service.dart) has a detailed comment in `_platformLocationSettings()` explaining exactly why `foregroundNotificationConfig` is deliberately absent — **read this comment before touching this file**, it's load-bearing documentation of the bug.
- [lib/features/tracking/providers/tracking_provider.dart](lib/features/tracking/providers/tracking_provider.dart) has a `// NOTE:` comment block right after the permission check in `startTracking()` marking where `requestBackgroundPermission()` and a `POST_NOTIFICATIONS` runtime request used to be called — they're currently removed/commented out, to be restored once the new native bridge actually makes background tracking work.
- A separate, **unrelated** bug was also found during this same testing session: step counting (via the `pedometer` package) freezes after an initial burst of events even while the user keeps walking (confirmed via GPS distance still increasing). This is believed to be Android/OEM step-sensor batching behavior, not a bug we introduced. **This is explicitly out of scope for this plan** — do not attempt to fix it here, it needs its own separate investigation.

---

## Phase 0 — Read before starting

- [ ] Read [GEOLOCATION_PLUGIN_PLAN.md](GEOLOCATION_PLUGIN_PLAN.md) in full — it has the target Dart API shape, Android/iOS implementation details, and the three explicit decisions already made (iOS is Android-only-tested for now; battery-optimization prompt is proactive; notification tap opens the app).
- [ ] Read the comment blocks referenced above in `location_service.dart` and `tracking_provider.dart` so the "why" behind the current (foreground-only) state is understood before changing it.
- [ ] Confirm device/testing setup: only a physical Android device is available for real verification (Motorola edge 50 fusion tested previously); iOS code must be written to spec but cannot be verified end-to-end in this pass.

## Phase 1 — Android native location bridge

- [ ] Add `implementation("com.google.android.gms:play-services-location:21.3.0")` (or current stable) to `android/app/build.gradle.kts`.
- [ ] Create `android/app/src/main/kotlin/in/moops/stride/location/StrideLocationService.kt` — foreground `Service` wrapping `FusedLocationProviderClient`, starts foreground notification immediately in `onStartCommand`, forwards `Location` updates.
- [ ] Create `android/app/src/main/kotlin/in/moops/stride/location/StrideLocationPlugin.kt` — `FlutterPlugin` exposing `MethodChannel` (`stride/location/methods`) + `EventChannel` (`stride/location/events`), plus battery-optimization check/request methods.
- [ ] Wire notification tap → `PendingIntent` back to `MainActivity`.
- [ ] Update `AndroidManifest.xml`: replace the dead `geolocator` `<service>` entry with one for `StrideLocationService`; add `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` permission.
- [ ] Register the new plugin in `MainActivity.kt`.

## Phase 2 — iOS native location bridge (write-only, unverified)

- [ ] Create `ios/Runner/StrideLocationPlugin.swift` — `CLLocationManagerDelegate`-based bridge using the **same channel names** as Android so Dart code is platform-agnostic.
- [ ] Register in `AppDelegate.swift`.
- [ ] No `Info.plist` changes needed (already has what's required).
- [ ] Mark clearly in code comments and in the PR description that this is unverified on real hardware.

## Phase 3 — Dart-side integration

- [ ] Create `lib/features/tracking/providers/native_location_service.dart` (`NativeLocationService` + `LocationFix` classes per the plan doc's target API).
- [ ] Delete `lib/features/tracking/providers/location_service.dart`.
- [ ] Remove `geolocator` (and transitively `geolocator_android`/`geolocator_apple`) from `pubspec.yaml`; run `flutter pub get`.
- [ ] Update `tracking_provider.dart`: swap `Position` → `LocationFix`, point `locationServiceProvider` at `NativeLocationService`, re-enable `requestBackgroundPermission()` + `POST_NOTIFICATIONS` request (remove the `NOTE:` comment once this is done), add the battery-optimization prompt flow.
- [ ] Implement Haversine distance calculation in pure Dart (replacing `Geolocator.distanceBetween`).

## Phase 4 — Testing (Android only, real device)

- [ ] Regression check: foreground tracking still works exactly as before (distance/pace/route update live).
- [ ] Background check: start a run, lock the screen, walk 60+ seconds, unlock, confirm distance/route kept accumulating the whole time.
- [ ] Confirm persistent notification appears, and tapping it re-opens the app.
- [ ] Confirm the battery-optimization prompt appears (on a fresh install / before the exemption is granted) and that granting it via the system dialog is reflected correctly (`isIgnoringBatteryOptimizations()` returns true afterward).
- [ ] Re-check Doze-mode survival over a longer window (5+ minutes locked) given this specific Motorola device showed OEM-specific aggressive battery behavior during earlier testing (`dumpsys deviceidle whitelist` was empty for the app).

## Phase 5 — Cleanup

- [ ] Remove this file (`todo_urgent.md`) and `GEOLOCATION_PLUGIN_PLAN.md` once the feature is shipped and verified, or fold any remaining open items into a normal tracked backlog.
- [ ] Double check no leftover references to `geolocator` remain (imports, pubspec, manifest comments).
