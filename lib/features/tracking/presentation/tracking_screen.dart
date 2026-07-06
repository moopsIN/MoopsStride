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
    // Do not start tracking automatically, let user press the start button.
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
      if (trackingState.status == TrackingStatus.active && !trackingState.isLocked) {
         WidgetsBinding.instance.addPostFrameCallback((_) {
           _mapController.move(trackingState.currentLocation!, _mapController.camera.zoom);
         });
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. FlutterMap Layer
          IgnorePointer(
            ignoring: trackingState.isLocked,
            child: FlutterMap(
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
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),

          // Dim overlay
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),

          // 2. Controls & Stats (Bottom)
          Positioned(
            bottom: 48,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!trackingState.isLocked) ...[
                  GlassContainer(
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
                  ).animate().slideY(begin: 0.2).fadeIn(duration: 400.ms),
                  const SizedBox(height: 32),
                ],
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildControls(context, trackingState),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, TrackingState state) {
    if (state.isLocked) {
      return _buildControlButton(
        icon: Icons.lock_open,
        color: Colors.white,
        onTap: () => ref.read(trackingProvider.notifier).toggleLock(),
      ).animate().scale(duration: 200.ms);
    }

    if (state.status == TrackingStatus.notStarted) {
      return _buildCircularProgressStartButton(state);
    }

    if (state.status == TrackingStatus.active) {
      return Column(
        children: [
          _buildControlButton(
            icon: Icons.pause,
            color: Colors.amber,
            onTap: () => ref.read(trackingProvider.notifier).pauseTracking(),
          ).animate().scale(duration: 200.ms),
          const SizedBox(height: 16),
          _buildControlButton(
            icon: Icons.lock_outline,
            color: Colors.grey,
            size: 60,
            iconSize: 28,
            onTap: () => ref.read(trackingProvider.notifier).toggleLock(),
          ).animate().slideY(begin: 0.5).fadeIn(),
        ],
      );
    }

    if (state.status == TrackingStatus.paused) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildControlButton(
            icon: Icons.stop,
            color: Colors.redAccent,
            onTap: _finishRun,
          ).animate().slideX(begin: 0.5).fadeIn(),
          const SizedBox(width: 32),
          _buildControlButton(
            icon: Icons.play_arrow,
            color: Theme.of(context).colorScheme.primary,
            onTap: () => ref.read(trackingProvider.notifier).resumeTracking(),
          ).animate().slideX(begin: -0.5).fadeIn(),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCircularProgressStartButton(TrackingState state) {
    int goal = 1000;
    if (state.dailySteps >= 1000) goal = 2000;
    if (state.dailySteps >= 2000) goal = 5000;
    if (state.dailySteps >= 5000) goal = 10000;
    if (state.dailySteps >= 10000) goal = 15000;
    if (state.dailySteps >= 15000) goal = 20000;
    
    final progress = (state.dailySteps / goal).clamp(0.0, 1.0);

    return Column(
      children: [
        Text(
          'DAILY STEPS: \${state.dailySteps} / $goal',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 2,
            color: Colors.white,
            shadows: [const Shadow(blurRadius: 4, color: Colors.black87)],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 8,
                      backgroundColor: Colors.black45,
                      color: Theme.of(context).colorScheme.primary,
                    );
                  },
                ),
              ),
              _buildControlButton(
                icon: Icons.play_arrow,
                color: Theme.of(context).colorScheme.primary,
                size: 80,
                iconSize: 40,
                onTap: () async {
                  final success = await ref.read(trackingProvider.notifier).startTracking();
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enable Location Services and grant permissions to track your run.'),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ).animate().scale(duration: 400.ms),
      ],
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

  Widget _buildControlButton({
    required IconData icon, 
    required Color color, 
    required VoidCallback onTap,
    double size = 80,
    double iconSize = 40,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
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
        child: Icon(icon, size: iconSize, color: Colors.black87),
      ),
    );
  }
}
