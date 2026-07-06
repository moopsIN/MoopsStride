import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stride/features/tracking/providers/location_service.dart';
import 'package:uuid/uuid.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/tracking/models/activity_model.dart';
import 'package:stride/features/sync/providers/sync_engine.dart';

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
    );
  }
  
  double get distanceKm => distanceMeters / 1000.0;
  
  // Pace in minutes per kilometer
  double get currentPace {
    if (distanceKm == 0) return 0.0;
    final minutes = durationSeconds / 60.0;
    return minutes / distanceKm;
  }
  
  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  String get formattedPace {
    if (currentPace == 0) return "--:--";
    final p = currentPace;
    final minutes = p.truncate();
    final seconds = ((p - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class TrackingNotifier extends Notifier<TrackingState> {
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<StepCount>? _globalStepSubscription;
  Timer? _timer;
  int? _runInitialSteps;

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

    _accumulatedDuration = Duration.zero;
    _lastResumedAt = DateTime.now();

    state = state.copyWith(status: TrackingStatus.active, startTime: DateTime.now());

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status == TrackingStatus.active) {
        _tickDuration();
      }
    });

    _runInitialSteps = null;

    _positionSubscription = locService.getPositionStream().listen((Position position) {
      if (state.status != TrackingStatus.active) return;
      
      final newPoint = LatLng(position.latitude, position.longitude);
      
      double addedDistance = 0;
      if (state.routePoints.isNotEmpty) {
        addedDistance = locService.calculateDistance(state.routePoints.last, newPoint);
      }
      
      state = state.copyWith(
        currentLocation: newPoint,
        routePoints: [...state.routePoints, newPoint],
        distanceMeters: state.distanceMeters + addedDistance,
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

  void resumeTracking() {
    _lastResumedAt = DateTime.now();
    state = state.copyWith(status: TrackingStatus.active);
  }

  Future<ActivityModel?> stopTracking() async {
    _tickDuration();
    state = state.copyWith(status: TrackingStatus.stopped);
    _timer?.cancel();
    _positionSubscription?.cancel();
    
    // In Phase 5/6, we will trigger save logic here.
    if (state.distanceMeters < 10 || state.durationSeconds < 10) return null; // Too short to save

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
      avgPace: state.currentPace,
      caloriesEstimate: state.distanceMeters * 0.06,
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
