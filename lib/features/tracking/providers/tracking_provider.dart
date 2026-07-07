import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:stride/features/tracking/providers/native_location_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/tracking/models/activity_model.dart';
import 'package:stride/features/sync/providers/sync_engine.dart';
import 'package:stride/features/profile/providers/profile_provider.dart';

enum TrackingStatus { notStarted, active, paused, stopped }

class TrackingState {
  final TrackingStatus status;
  final List<LatLng> routePoints;
  final double distanceMeters;
  final int durationSeconds;
  final DateTime? startTime;
  final LatLng? currentLocation;
  final int currentSteps;
  final int dailySteps;
  final bool isLocked;
  final String? errorMessage;
  final double speedKmH;
  final double caloriesEstimate;

  TrackingState({
    this.status = TrackingStatus.notStarted,
    this.routePoints = const [],
    this.distanceMeters = 0.0,
    this.durationSeconds = 0,
    this.startTime,
    this.currentLocation,
    this.currentSteps = 0,
    this.dailySteps = 0,
    this.isLocked = false,
    this.errorMessage,
    this.speedKmH = 0.0,
    this.caloriesEstimate = 0.0,
  });

  TrackingState copyWith({
    TrackingStatus? status,
    List<LatLng>? routePoints,
    double? distanceMeters,
    int? durationSeconds,
    DateTime? startTime,
    LatLng? currentLocation,
    int? currentSteps,
    int? dailySteps,
    bool? isLocked,
    String? errorMessage,
    bool clearErrorMessage = false,
    double? speedKmH,
    double? caloriesEstimate,
  }) {
    return TrackingState(
      status: status ?? this.status,
      routePoints: routePoints ?? this.routePoints,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startTime: startTime ?? this.startTime,
      currentLocation: currentLocation ?? this.currentLocation,
      currentSteps: currentSteps ?? this.currentSteps,
      dailySteps: dailySteps ?? this.dailySteps,
      isLocked: isLocked ?? this.isLocked,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      speedKmH: speedKmH ?? this.speedKmH,
      caloriesEstimate: caloriesEstimate ?? this.caloriesEstimate,
    );
  }

  double get distanceKm => distanceMeters / 1000.0;

  // Speed in km/h, recomputed every 10s from elapsed time
  // and recorded distance (see TrackingNotifier._tickSpeed) rather than on
  // every GPS fix or duration tick — coarse on purpose, avoids jitter.
  double get currentSpeed => speedKmH;

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  String get formattedSpeed {
    if (currentSpeed == 0) return "0.0";
    return currentSpeed.toStringAsFixed(1);
  }
}

class TrackingNotifier extends Notifier<TrackingState> {
  StreamSubscription<LocationFix>? _positionSubscription;
  StreamSubscription<StepCount>? _globalStepSubscription;
  Timer? _timer;
  Timer? _speedTimer;
  int? _runInitialSteps;

  // --- GPS filtering, tuned for walking & running ---
  // Drop fixes whose reported horizontal accuracy is worse than this (meters),
  // or negative (invalid). Poor fixes — common at cold start or near buildings
  // — are the main source of phantom distance and erratic pace.
  static const double _maxAccuracyMeters = 30.0;
  // Ignore movement below this between two accepted points (meters), so
  // standing still or small GPS drift doesn't accumulate fake distance. This
  // backs up the native displacement filter in case the platforms disagree.
  static const double _minMoveMeters = 3.0;

  // Duration is derived from wall-clock time rather than counted by the
  // Timer tick, since the OS can suspend Dart timers while the app is
  // backgrounded/the device is locked — ticks would be lost, but elapsed
  // real time is always correct once the app resumes.
  DateTime? _lastResumedAt;
  Duration _accumulatedDuration = Duration.zero;

  Duration _currentElapsed() {
    if (_lastResumedAt == null) return _accumulatedDuration;
    return _accumulatedDuration + DateTime.now().difference(_lastResumedAt!);
  }

  void _tickDuration() {
    state = state.copyWith(durationSeconds: _currentElapsed().inSeconds);
  }

  int _lastSpeedTickSeconds = 0;

  // Speed is recomputed every 10s from elapsed time and recorded distance so
  // far, rather than on every GPS fix — a deliberately coarse average that
  // doesn't need to be precise, just present and roughly right.
  static const double _minDistanceForSpeedMeters = 20.0;

  void _tickSpeed() {
    final currentElapsedSeconds = _currentElapsed().inSeconds;
    final tickDurationSeconds = currentElapsedSeconds - _lastSpeedTickSeconds;
    _lastSpeedTickSeconds = currentElapsedSeconds;

    final distanceKm = state.distanceMeters / 1000.0;
    
    if (state.distanceMeters < _minDistanceForSpeedMeters || currentElapsedSeconds == 0) {
      state = state.copyWith(speedKmH: 0.0);
      return;
    }
    
    final hours = currentElapsedSeconds / 3600.0;
    final currentSpeedKmH = distanceKm / hours;

    // Calculate calories for this tick using ACSM METs equations
    double tickCalories = 0.0;
    if (tickDurationSeconds > 0 && currentSpeedKmH > 0) {
      final speedMMin = currentSpeedKmH * 16.67; // km/h to m/min
      // Assuming 0% grade. Walking equation for < 8 km/h, Running equation for >= 8 km/h
      final vo2 = currentSpeedKmH >= 8.0 
          ? (0.2 * speedMMin) + 3.5 
          : (0.1 * speedMMin) + 3.5;
      final mets = vo2 / 3.5;
      
      final profile = ref.read(profileProvider).value;
      final weight = profile?.weight ?? 70.0;
      final height = profile?.height ?? 170.0;
      final age = profile?.age ?? 25;
      final gender = profile?.gender ?? 'Male';

      // Calculate BMR using Mifflin-St Jeor equation for higher accuracy
      double bmr;
      if (gender.toLowerCase() == 'female') {
        bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
      } else {
        bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
      }

      // Convert BMR to per-minute rate and multiply by METs
      final caloriesPerMin = (bmr / 1440.0) * mets;
      tickCalories = caloriesPerMin * (tickDurationSeconds / 60.0);
    }

    state = state.copyWith(
      speedKmH: currentSpeedKmH,
      caloriesEstimate: state.caloriesEstimate + tickCalories,
    );
  }

  @override
  TrackingState build() {
    _initCurrentLocation();
    _initDailySteps();
    return TrackingState();
  }

  Future<void> _initDailySteps() async {
    if (Platform.isAndroid) {
      final activityStatus = await Permission.activityRecognition.status;
      if (!activityStatus.isGranted) {
        await Permission.activityRecognition.request();
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    
    _globalStepSubscription ??= Pedometer.stepCountStream.listen((StepCount event) {
      final today = DateTime.now();
      final dateString = "${today.year}-${today.month}-${today.day}";
      
      final savedDate = prefs.getString('last_step_date');
      int midnightOffset = prefs.getInt('midnight_step_offset') ?? event.steps;

      if (savedDate != dateString) {
        midnightOffset = event.steps;
        prefs.setString('last_step_date', dateString);
        prefs.setInt('midnight_step_offset', midnightOffset);
      }
      
      final currentDaily = event.steps - midnightOffset;

      int currentRun = state.currentSteps;
      if (state.status == TrackingStatus.active) {
        _runInitialSteps ??= event.steps;
        currentRun = event.steps - _runInitialSteps!;
      }
      
      state = state.copyWith(
        dailySteps: currentDaily > 0 ? currentDaily : 0, 
        currentSteps: currentRun
      );
    }, onError: (e) {
      debugPrint("Global pedometer error: $e");
    });
  }

  void toggleLock() {
    state = state.copyWith(isLocked: !state.isLocked);
  }

  Future<void> _initCurrentLocation() async {
    final locService = ref.read(locationServiceProvider);
    final pos = await locService.getCurrentPosition();
    if (pos != null) {
      state = state.copyWith(currentLocation: LatLng(pos.latitude, pos.longitude));
    }
  }

  Future<bool> startTracking() async {
    final locService = ref.read(locationServiceProvider);
    final hasPerm = await locService.requestPermission();
    if (!hasPerm) return false;

    await locService.requestBackgroundPermission();
    if (Platform.isAndroid) {
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await Permission.notification.request();
      }

      final isIgnoring = await locService.isIgnoringBatteryOptimizations();
      if (!isIgnoring) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('battery_prompt_shown') != true) {
          await prefs.setBool('battery_prompt_shown', true);
          await locService.requestIgnoreBatteryOptimizations();
        }
      }
    }

    final serviceStarted = await locService.startService();
    if (!serviceStarted) return false;

    _accumulatedDuration = Duration.zero;
    _lastSpeedTickSeconds = 0;
    _lastResumedAt = DateTime.now();

    state = state.copyWith(status: TrackingStatus.active, startTime: DateTime.now());

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status == TrackingStatus.active) {
        _tickDuration();
      }
    });

    _speedTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (state.status == TrackingStatus.active) {
        _tickSpeed();
      }
    });

    _runInitialSteps = null;

    _positionSubscription = locService.getPositionStream().listen((LocationFix position) {
      if (state.status != TrackingStatus.active) return;

      // Reject unreliable fixes (negative = invalid on iOS; large accuracy =
      // low confidence). These are what made distance/pace jump around.
      final accuracy = position.accuracy;
      if (accuracy != null && (accuracy < 0 || accuracy > _maxAccuracyMeters)) {
        return;
      }

      final newPoint = LatLng(position.latitude, position.longitude);

      // Seed the route with the first good fix; no distance yet.
      if (state.routePoints.isEmpty) {
        state = state.copyWith(
          currentLocation: newPoint,
          routePoints: [newPoint],
        );
        return;
      }

      final moved = locService.calculateDistance(state.routePoints.last, newPoint);
      // Below the noise floor: keep the route/distance stable instead of
      // accumulating drift while effectively standing still.
      if (moved < _minMoveMeters) return;

      state = state.copyWith(
        currentLocation: newPoint,
        routePoints: [...state.routePoints, newPoint],
        distanceMeters: state.distanceMeters + moved,
      );
    }, onError: (e) {
      debugPrint("Position stream error: $e");
      if (state.status == TrackingStatus.active) {
        pauseTracking();
      }
      state = state.copyWith(
        errorMessage: 'Location permission was lost, so tracking has been paused.',
      );
    });

    return true;
  }

  void pauseTracking() {
    if (_lastResumedAt != null) {
      _accumulatedDuration += DateTime.now().difference(_lastResumedAt!);
      _lastResumedAt = null;
    }
    state = state.copyWith(status: TrackingStatus.paused);
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }

  void resumeTracking() {
    _lastResumedAt = DateTime.now();
    state = state.copyWith(status: TrackingStatus.active);
  }

  Future<ActivityModel?> stopTracking() async {
    _tickDuration();
    _tickSpeed();
    state = state.copyWith(status: TrackingStatus.stopped);
    _timer?.cancel();
    _speedTimer?.cancel();
    _positionSubscription?.cancel();
    
    await ref.read(locationServiceProvider).stopService();
    
    // If you want to reject short runs in the future, add it here.
    // For now, always show the summary screen.

    final id = const Uuid().v4();
    final endTime = DateTime.now();
    final startTime = state.startTime ?? endTime.subtract(Duration(seconds: state.durationSeconds));
    
    final activity = ActivityModel(
      id: id,
      type: 'run',
      startTime: startTime,
      endTime: endTime,
      distanceMeters: state.distanceMeters,
      durationSeconds: state.durationSeconds,
      avgPace: state.currentSpeed > 0 ? (60.0 / state.currentSpeed) : 0.0,
      caloriesEstimate: state.caloriesEstimate,
      routePoints: state.routePoints,
      steps: state.currentSteps,
      synced: false,
    );
    
    await LocalDatabase.instance.insertActivity(activity.toMap());
    
    // Trigger sync to cloud
    ref.read(syncEngineProvider).syncUnsyncedActivities();
    
    return activity;
  }

  void reset() {
    _timer?.cancel();
    _speedTimer?.cancel();
    _positionSubscription?.cancel();
    _accumulatedDuration = Duration.zero;
    _lastResumedAt = null;
    state = TrackingState();
    _initCurrentLocation();
  }
}

final trackingProvider = NotifierProvider<TrackingNotifier, TrackingState>(() {
  return TrackingNotifier();
});
