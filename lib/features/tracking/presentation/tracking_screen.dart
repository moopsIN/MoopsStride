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
      // Run was too short to save; just reset back to the idle state.
      ref.read(trackingProvider.notifier).reset();
      return;
    }
    
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RunSummaryScreen(activity: activity),
      ),
    );

    if (!mounted) return;
    ref.read(trackingProvider.notifier).reset();
  }

  static const double _idleZoom = 16.0;
  static const double _activeZoom = 18.0;
  bool _hasZoomedForActiveRun = false;

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingProvider);

    ref.listen<TrackingState>(trackingProvider, (previous, next) {
      final message = next.errorMessage;
      if (message != null) {
        ref.read(trackingProvider.notifier).clearError();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    });

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

    final hasStarted = trackingState.status != TrackingStatus.notStarted;

    const greyscaleMatrix = <double>[
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0,      0,      0,      1, 0,
    ];

    final baseUi = Stack(
      children: [
        // 1. FlutterMap Layer
        IgnorePointer(
          ignoring: trackingState.isLocked,
          child: FlutterMap(
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

        // Header (always present)
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: _buildHomeHeader(context),
        ),

        // 2. Stats (dead center)
        if (hasStarted)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
              ).animate().slideY(begin: 0.2).fadeIn(duration: 400.ms),
            ),
          ),

        // 3. Controls (66% from top)
        Align(
          alignment: const Alignment(0, 0.33),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (hasStarted) ...[
                if (trackingState.isLocked)
                  const SizedBox(width: 52, height: 52)
                else
                  _buildControlButton(
                    icon: Icons.lock_open,
                    color: Colors.white.withValues(alpha: 0.15),
                    size: 52,
                    iconSize: 22,
                    onTap: () => ref.read(trackingProvider.notifier).toggleLock(),
                  ).animate().fadeIn(duration: 300.ms),
                const SizedBox(width: 20),
              ],

              _buildMainToggleButton(context, trackingState),

              if (hasStarted) ...[
                const SizedBox(width: 20),
                _buildControlButton(
                  icon: Icons.stop,
                  color: Colors.redAccent,
                  size: 52,
                  iconSize: 22,
                  onTap: _finishRun,
                ).animate().fadeIn(duration: 300.ms),
              ],
            ],
          ),
        ),

        // 4. Branding
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 32.0),
            child: Text(
              'Stride by Moops',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white54,
                letterSpacing: 2,
              ),
            ).animate().fadeIn(delay: 500.ms),
          ),
        ),
      ],
    );

    return Scaffold(
      body: Stack(
        children: [
          // Base layer with greyscale & ignore pointer when locked
          ColorFiltered(
            colorFilter: trackingState.isLocked
                ? const ColorFilter.matrix(greyscaleMatrix)
                : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: IgnorePointer(
              ignoring: trackingState.isLocked,
              child: baseUi,
            ),
          ),
          
          // Lock overlay interactive layer (perfectly aligns via exact alignments)
          if (trackingState.isLocked)
            Stack(
              children: [
                Align(
                  alignment: const Alignment(0, 0.33),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (hasStarted) ...[
                        _buildControlButton(
                          icon: Icons.lock,
                          color: Colors.white,
                          size: 52,
                          iconSize: 22,
                          onTap: () => ref.read(trackingProvider.notifier).toggleLock(),
                        ).animate().fadeIn(duration: 300.ms),
                        const SizedBox(width: 20),
                      ],
                      Opacity(opacity: 0, child: IgnorePointer(child: _buildMainToggleButton(context, trackingState))),
                      if (hasStarted) ...[
                        const SizedBox(width: 20),
                        Opacity(
                          opacity: 0,
                          child: _buildControlButton(
                            icon: Icons.stop,
                            color: Colors.redAccent,
                            size: 52,
                            iconSize: 22,
                            onTap: () {},
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMainToggleButton(BuildContext context, TrackingState state) {
    final isActive = state.status == TrackingStatus.active;
    final isNotStarted = state.status == TrackingStatus.notStarted;

    final label = isNotStarted ? 'START' : (isActive ? 'PAUSE' : 'RESUME');
    const green = Color(0xFF4CAF6D);
    const fadedYellow = Color(0xFFE6C55C);
    final color = isActive ? fadedYellow : green;
    final size = isNotStarted ? 200.0 : 140.0;

    return GestureDetector(
      key: ValueKey(state.status),
      onTap: () async {
        final notifier = ref.read(trackingProvider.notifier);
        if (isNotStarted) {
          final success = await notifier.startTracking();
          if (!success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enable Location Services and grant permissions to track your run.'),
              ),
            );
          }
        } else if (isActive) {
          notifier.pauseTracking();
        } else {
          notifier.resumeTracking();
        }
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 24,
              spreadRadius: 2,
            )
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 1.5,
          ),
        ),
      ),
    ).animate(key: ValueKey(state.status)).scale(duration: 200.ms);
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
