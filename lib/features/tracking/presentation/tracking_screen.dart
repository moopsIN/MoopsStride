import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/features/tracking/providers/tracking_provider.dart';
import 'package:stride/theme/glass_container.dart';
import 'package:stride/core/config/secrets.dart';
import 'package:stride/features/tracking/presentation/run_summary_screen.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Start tracking as soon as screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trackingProvider.notifier).startTracking();
    });
  }

  Future<void> _finishRun() async {
    final activity = await ref.read(trackingProvider.notifier).stopTracking();
    if (!mounted) return;
    
    if (activity == null) {
      // Run was too short, just pop
      Navigator.of(context).pop();
      return;
    }
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RunSummaryScreen(activity: activity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingProvider);

    // Update map camera if we have a location
    if (trackingState.currentLocation != null) {
      // In flutter_map, we can use move to recenter the map on the current location.
      // We only do this if tracking is active so the user isn't pulled back if they scroll around while paused.
      if (trackingState.status == TrackingStatus.active) {
         WidgetsBinding.instance.addPostFrameCallback((_) {
           _mapController.move(trackingState.currentLocation!, _mapController.camera.zoom);
         });
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. FlutterMap Layer (OpenStreetMap via MapTiler)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: trackingState.currentLocation ?? const LatLng(0, 0),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://api.maptiler.com/maps/dataviz-dark/{z}/{x}/{y}.png?key=${Secrets.mapTilerKey}',
                userAgentPackageName: 'com.moops.stride',
              ),
              PolylineLayer(
                polylines: [
                  if (trackingState.routePoints.isNotEmpty)
                    Polyline(
                      points: trackingState.routePoints,
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors',
                  ),
                ],
              ),
            ],
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
                  _buildStatItem('STEPS', trackingState.currentSteps.toString()),
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
          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
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
