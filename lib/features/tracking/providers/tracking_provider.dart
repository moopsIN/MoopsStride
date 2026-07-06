import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:stride/features/tracking/providers/location_service.dart';
import 'package:uuid/uuid.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/tracking/models/activity_model.dart';

enum TrackingStatus { notStarted, active, paused, stopped }

class TrackingState {
  final TrackingStatus status;
  final List<LatLng> routePoints;
  final double distanceMeters;
  final int durationSeconds;
  final DateTime? startTime;
  final LatLng? currentLocation;

  TrackingState({
    this.status = TrackingStatus.notStarted,
    this.routePoints = const [],
    this.distanceMeters = 0.0,
    this.durationSeconds = 0,
    this.startTime,
    this.currentLocation,
  });

  TrackingState copyWith({
    TrackingStatus? status,
    List<LatLng>? routePoints,
    double? distanceMeters,
    int? durationSeconds,
    DateTime? startTime,
    LatLng? currentLocation,
  }) {
    return TrackingState(
      status: status ?? this.status,
      routePoints: routePoints ?? this.routePoints,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startTime: startTime ?? this.startTime,
      currentLocation: currentLocation ?? this.currentLocation,
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
  Timer? _timer;

  @override
  TrackingState build() {
    // Initial fetch of current location to center map before starting
    _initCurrentLocation();
    return TrackingState();
  }

  Future<void> _initCurrentLocation() async {
    final locService = ref.read(locationServiceProvider);
    final pos = await locService.getCurrentPosition();
    if (pos != null) {
      state = state.copyWith(currentLocation: LatLng(pos.latitude, pos.longitude));
    }
  }

  Future<void> startTracking() async {
    final locService = ref.read(locationServiceProvider);
    final hasPerm = await locService.requestPermission();
    if (!hasPerm) return;

    state = state.copyWith(status: TrackingStatus.active, startTime: DateTime.now());
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status == TrackingStatus.active) {
        state = state.copyWith(durationSeconds: state.durationSeconds + 1);
      }
    });

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
  }

  void pauseTracking() {
    state = state.copyWith(status: TrackingStatus.paused);
  }

  void resumeTracking() {
    state = state.copyWith(status: TrackingStatus.active);
  }

  Future<ActivityModel?> stopTracking() async {
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
      caloriesEstimate: state.distanceKm * 60.0, // rough estimate
      routePoints: state.routePoints,
      synced: false,
    );
    
    await LocalDatabase.instance.insertActivity(activity.toMap());
    
    return activity;
  }

  void reset() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    state = TrackingState();
    _initCurrentLocation();
  }
}

final trackingProvider = NotifierProvider<TrackingNotifier, TrackingState>(() {
  return TrackingNotifier();
});
