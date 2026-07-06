import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/features/tracking/providers/tracking_provider.dart';
import 'package:stride/theme/glass_container.dart';
import 'package:stride/core/config/secrets.dart';
import 'package:stride/features/tracking/presentation/run_summary_screen.dart';
import 'package:stride/features/profile/presentation/profile_screen.dart';
import 'package:stride/features/progress/providers/progress_provider.dart';
import 'package:stride/features/progress/presentation/progress_screen.dart';
import 'package:stride/features/sync/providers/sync_engine.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(progressProvider.notifier).refresh();
      ref.read(syncEngineProvider);
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

  static const double _idleZoom = 16.0;
  static const double _activeZoom = 18.0;
  bool _hasZoomedForActiveRun = false;

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingProvider);

    // Update map camera if we have a location
    if (trackingState.currentLocation != null) {
      if (trackingState.status == TrackingStatus.active) {
         final targetZoom = _hasZoomedForActiveRun ? _mapController.camera.zoom : _activeZoom;
         WidgetsBinding.instance.addPostFrameCallback((_) {
           _mapController.move(trackingState.currentLocation!, targetZoom);
         });
         _hasZoomedForActiveRun = true;
      } else if (trackingState.status == TrackingStatus.notStarted) {
        _hasZoomedForActiveRun = false;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. FlutterMap Layer
          FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: trackingState.currentLocation ?? const LatLng(0, 0),
                initialZoom: _idleZoom,
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

          // Dim overlay
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),

          // Home Header (Only when not started)
          if (trackingState.status == TrackingStatus.notStarted)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: _buildHomeHeader(context),
            ),

          // 2. Controls & Stats (Bottom)
          Positioned(
            bottom: 48,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trackingState.status != TrackingStatus.notStarted) ...[
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

                _buildMainToggleButton(context, trackingState),

                if (trackingState.status == TrackingStatus.active ||
                    trackingState.status == TrackingStatus.paused) ...[
                  const SizedBox(height: 24),
                  _buildControlButton(
                    icon: Icons.stop,
                    color: Colors.redAccent,
                    size: 56,
                    iconSize: 26,
                    onTap: _finishRun,
                  ).animate().slideY(begin: 0.3).fadeIn(delay: 100.ms),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainToggleButton(BuildContext context, TrackingState state) {
    if (state.status == TrackingStatus.notStarted) {
      return _buildCircularProgressStartButton(state);
    }

    final isActive = state.status == TrackingStatus.active;

    return _buildControlButton(
      key: ValueKey(isActive),
      icon: isActive ? Icons.pause : Icons.play_arrow,
      color: isActive
          ? Theme.of(context).colorScheme.secondary
          : Theme.of(context).colorScheme.primary,
      onTap: () {
        final notifier = ref.read(trackingProvider.notifier);
        if (isActive) {
          notifier.pauseTracking();
        } else {
          notifier.resumeTracking();
        }
      },
    ).animate(key: ValueKey(isActive)).scale(duration: 200.ms);
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
    Key? key,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 80,
    double iconSize = 40,
  }) {
    return GestureDetector(
      key: key,
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

  Widget _buildHomeHeader(BuildContext context) {
    final progressState = ref.watch(progressProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to run?',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 4),
                Text(
                  'Let\'s crush those goals today.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white),
              ),
            ),
          ],
        ).animate().slideY(begin: -0.2).fadeIn(duration: 400.ms),
        
        const SizedBox(height: 24),
        
        GlassContainer(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.local_fire_department, color: Theme.of(context).colorScheme.primary, size: 32),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${progressState.currentStreak} Day Streak', style: Theme.of(context).textTheme.titleLarge),
                  Text('Keep it up!', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProgressScreen()),
                  ).then((_) {
                    ref.read(progressProvider.notifier).refresh();
                  });
                },
                icon: const Icon(Icons.bar_chart, color: Colors.white70),
              ),
            ],
          ),
        ).animate().slideX(begin: 0.1, delay: 200.ms).fadeIn(delay: 200.ms),
      ],
    );
  }
}
