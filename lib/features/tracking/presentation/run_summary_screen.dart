import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/core/config/secrets.dart';
import 'package:stride/features/tracking/models/activity_model.dart';
import 'package:stride/theme/glass_container.dart';

class RunSummaryScreen extends StatelessWidget {
  final ActivityModel activity;

  const RunSummaryScreen({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    // Calculate bounding box for map to show entire route
    LatLngBounds? bounds;
    if (activity.routePoints.isNotEmpty) {
      bounds = LatLngBounds.fromPoints(activity.routePoints);
    }

    final String formattedDuration = _formatDuration(activity.durationSeconds);
    final String formattedPace = _formatPace(activity.avgPace);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Map Layer
          FlutterMap(
            options: MapOptions(
              initialCameraFit: bounds != null
                  ? CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(48.0),
                    )
                  : null,
              initialCenter: activity.routePoints.isNotEmpty
                  ? activity.routePoints.first
                  : const LatLng(0, 0),
              initialZoom: 15.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://api.maptiler.com/maps/dataviz-dark/{z}/{x}/{y}.png?key=${Secrets.mapTilerKey}',
                userAgentPackageName: 'com.moops.stride',
              ),
              PolylineLayer(
                polylines: [
                  if (activity.routePoints.isNotEmpty)
                    Polyline(
                      points: activity.routePoints,
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                ],
              ),
              if (activity.routePoints.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: activity.routePoints.first,
                      child: const Icon(Icons.circle, color: Colors.green, size: 16),
                    ),
                    Marker(
                      point: activity.routePoints.last,
                      child: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 20),
                    ),
                  ],
                ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ).animate().fadeIn(duration: 600.ms),

          // 2. Gradient Overlay for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor,
                    Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // 3. Stats and Actions
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Text(
                        'Run Completed',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                      ).animate().slideX(begin: -0.2).fadeIn(duration: 400.ms),
                    ],
                  ),
                ),

                const Spacer(),

                // Stat Cards (Staggered)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context, 
                              'DISTANCE', 
                              '${activity.distanceMeters.toStringAsFixed(0)}m',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              context, 
                              'TIME', 
                              formattedDuration,
                            ),
                          ),
                        ],
                      ).animate().slideY(begin: 0.2).fadeIn(delay: 200.ms),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context, 
                              'AVG PACE', 
                              formattedPace,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              context, 
                              'CALORIES', 
                              '${activity.caloriesEstimate.toStringAsFixed(0)}',
                            ),
                          ),
                        ],
                      ).animate().slideY(begin: 0.2).fadeIn(delay: 350.ms),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Done Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: Text(
                      'DONE',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.background,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ).animate().scale(delay: 500.ms, curve: Curves.easeOutBack),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatPace(double paceMinPerKm) {
    if (paceMinPerKm == 0) return "--:--";
    final minutes = paceMinPerKm.truncate();
    final seconds = ((paceMinPerKm - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
