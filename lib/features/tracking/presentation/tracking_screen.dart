import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/features/tracking/providers/tracking_provider.dart';
import 'package:stride/theme/glass_container.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  GoogleMapController? _mapController;

  // Modern dark styling for the map
  final String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#242f3e"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
    {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
    {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212a37"}]},
    {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9ca5b3"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#515c6d"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    // Start tracking as soon as screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trackingProvider.notifier).startTracking();
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController?.setMapStyle(_darkMapStyle);
  }

  void _finishRun() {
    ref.read(trackingProvider.notifier).stopTracking();
    Navigator.of(context).pop();
    // In Phase 5 we will navigate to Run Summary here
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingProvider);

    // Update map camera if we have a location
    if (_mapController != null && trackingState.currentLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(trackingState.currentLocation!),
      );
    }

    final Set<Polyline> polylines = {
      if (trackingState.routePoints.isNotEmpty)
        Polyline(
          polylineId: const PolylineId('route'),
          points: trackingState.routePoints,
          color: Theme.of(context).colorScheme.primary,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
    };

    return Scaffold(
      body: Stack(
        children: [
          // 1. Google Map Layer
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: trackingState.currentLocation ?? const LatLng(0, 0),
              zoom: 16.0,
            ),
            polylines: polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
          ),

          // 2. Stats Overlay (Top)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('TIME', trackingState.formattedDuration),
                  _buildStatItem('KM', trackingState.distanceKm.toStringAsFixed(2)),
                  _buildStatItem('PACE', trackingState.formattedPace),
                ],
              ),
            ).animate().slideY(begin: -0.2).fadeIn(duration: 400.ms),
          ),

          // 3. Controls Overlay (Bottom)
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (trackingState.status == TrackingStatus.active)
                  _buildControlButton(
                    icon: Icons.pause,
                    color: Colors.amber,
                    onTap: () => ref.read(trackingProvider.notifier).pauseTracking(),
                  ).animate().scale(duration: 200.ms)
                else if (trackingState.status == TrackingStatus.paused) ...[
                  _buildControlButton(
                    icon: Icons.stop,
                    color: Colors.redAccent,
                    onTap: _finishRun, // In real app, might want a long press or confirmation
                  ).animate().slideX(begin: 0.5).fadeIn(),
                  const SizedBox(width: 32),
                  _buildControlButton(
                    icon: Icons.play_arrow,
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () => ref.read(trackingProvider.notifier).resumeTracking(),
                  ).animate().slideX(begin: -0.5).fadeIn(),
                ] else if (trackingState.status == TrackingStatus.notStarted) ...[
                  const CircularProgressIndicator(),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 2),
        ),
      ],
    );
  }

  Widget _buildControlButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child: Icon(icon, size: 40, color: Colors.black87),
      ),
    );
  }
}
