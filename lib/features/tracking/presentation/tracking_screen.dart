import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/features/tracking/providers/tracking_provider.dart';
import 'package:stride/theme/glass_container.dart';
import 'package:stride/core/config/secrets.dart';
import 'package:stride/features/tracking/presentation/run_summary_screen.dart';
import 'package:stride/core/providers/preferences_provider.dart';
import 'package:stride/features/profile/presentation/profile_screen.dart';
import 'package:stride/features/progress/providers/progress_provider.dart';
import 'package:stride/features/progress/presentation/progress_screen.dart';
import 'package:stride/features/sync/providers/sync_engine.dart';
import 'package:stride/features/profile/providers/profile_provider.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final MapController _mapController = MapController();

  static const Color _goGreen = Color(0xFF55A870); // Muted green
  static const Color _pauseAmber = Color(0xFFD0A558); // Muted amber
  static const Color _stopRed = Color(0xFFE5484D);

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

  static const double _idleZoom = 18.0;
  static const double _activeZoom = 19.5;
  bool _hasZoomedForActiveRun = false;
  bool _isMapReady = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
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
    final mapStyle = isDark ? 'dataviz-dark' : 'dataviz';

    const greyscaleMatrix = <double>[
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0, 0, 0, 1, 0,
    ];

    final baseUi = Stack(
      children: [
        // 1. FlutterMap Layer — style follows the theme.
        IgnorePointer(
          ignoring: trackingState.isLocked,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 800),
            opacity: _isMapReady ? 1.0 : 0.0,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: trackingState.currentLocation ?? const LatLng(0, 0),
                initialZoom: _idleZoom,
                onMapReady: () {
                  if (mounted) {
                    setState(() => _isMapReady = true);
                  }
                },
              ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.maptiler.com/maps/$mapStyle/{z}/{x}/{y}.png?key=${Secrets.mapTilerKey}',
                userAgentPackageName: 'com.moops.stride',
              ),
              PolylineLayer(
                polylines: [
                  if (trackingState.routePoints.isNotEmpty) ...[
                    Polyline(
                      points: trackingState.routePoints,
                      color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.35),
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                    Polyline(
                      points: trackingState.routePoints,
                      color: theme.colorScheme.primary,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
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
        ),

        // 2. Theme-matched scrim: darkens/lightens toward the theme background
        //    at the top (header) and bottom (controls) for legibility, while
        //    keeping the map visible through the middle band.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bg.withValues(alpha: 0.88),
                    bg.withValues(alpha: 0.30),
                    bg.withValues(alpha: 0.30),
                    bg.withValues(alpha: 0.92),
                  ],
                  stops: const [0.0, 0.26, 0.58, 1.0],
                ),
              ),
            ),
          ),
        ),

        // Header (always present)
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20,
          right: 20,
          child: _buildHomeHeader(context, trackingState),
        ),

        // 3. Stats (centered, above the controls)
        if (hasStarted)
          Align(
            alignment: const Alignment(0, -0.02),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _buildStatsPanel(context, trackingState, ref)
                  .animate()
                  .slideY(begin: 0.2, curve: Curves.easeOut)
                  .fadeIn(duration: 400.ms),
            ),
          ),

        // 4. Controls (lower third)
        Align(
          alignment: const Alignment(0, 0.4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (hasStarted) ...[
                if (trackingState.isLocked)
                  const SizedBox(width: 54, height: 54)
                else
                  _buildControlButton(
                    icon: Icons.lock_open_rounded,
                    color: theme.colorScheme.surface.withValues(alpha: 0.92),
                    iconColor: theme.colorScheme.onSurface,
                    borderColor: theme.dividerColor,
                    size: 54,
                    iconSize: 22,
                    onTap: () => ref.read(trackingProvider.notifier).toggleLock(),
                  ).animate().fadeIn(duration: 300.ms),
                const SizedBox(width: 24),
              ],

              _buildMainToggleButton(context, trackingState),

              if (hasStarted) ...[
                const SizedBox(width: 24),
                _buildControlButton(
                  icon: Icons.stop_rounded,
                  color: _stopRed,
                  iconColor: Colors.white,
                  size: 54,
                  iconSize: 24,
                  onTap: _finishRun,
                ).animate().fadeIn(duration: 300.ms),
              ],
            ],
          ),
        ),

      ],
    );

    return Scaffold(
      body: Stack(
        children: [
          // Base layer, desaturated + non-interactive while locked.
          ColorFiltered(
            colorFilter: trackingState.isLocked
                ? const ColorFilter.matrix(greyscaleMatrix)
                : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: IgnorePointer(
              ignoring: trackingState.isLocked,
              child: baseUi,
            ),
          ),

          // Interactive unlock control, aligned exactly over the base controls.
          if (trackingState.isLocked)
            Align(
              alignment: const Alignment(0, 0.4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (hasStarted) ...[
                    _buildControlButton(
                      icon: Icons.lock_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      iconColor: Colors.white,
                      size: 54,
                      iconSize: 22,
                      onTap: () => ref.read(trackingProvider.notifier).toggleLock(),
                    ).animate().fadeIn(duration: 300.ms),
                    const SizedBox(width: 24),
                  ],
                  Opacity(
                    opacity: 0,
                    child: IgnorePointer(child: _buildMainToggleButton(context, trackingState)),
                  ),
                  if (hasStarted) ...[
                    const SizedBox(width: 24),
                    Opacity(
                      opacity: 0,
                      child: _buildControlButton(
                        icon: Icons.stop_rounded,
                        color: _stopRed,
                        size: 54,
                        iconSize: 24,
                        onTap: () {},
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainToggleButton(BuildContext context, TrackingState state) {
    final theme = Theme.of(context);
    final isActive = state.status == TrackingStatus.active;
    final isNotStarted = state.status == TrackingStatus.notStarted;

    final label = isNotStarted ? 'START' : (isActive ? 'PAUSE' : 'RESUME');
    final color = isActive ? _pauseAmber : _goGreen;
    final size = isNotStarted ? 184.0 : 132.0;

    return GestureDetector(
      key: ValueKey(state.status),
      onTap: () async {
        final notifier = ref.read(trackingProvider.notifier);
        if (isNotStarted) {
          final success = await notifier.startTracking();
          if (!success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Please enable Location Services and grant permissions to track your run.'),
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
          border: Border.all(
            color: theme.scaffoldBackgroundColor.withValues(alpha: 0.6),
            width: 5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 30,
              spreadRadius: 1,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: Colors.black.withValues(alpha: 0.8),
            fontWeight: FontWeight.w800,
            fontSize: isNotStarted ? 22 : 18,
            letterSpacing: 2,
          ),
        ),
      ),
    ).animate(key: ValueKey(state.status)).scale(
          duration: 260.ms,
          curve: Curves.easeOutBack,
          begin: const Offset(0.85, 0.85),
        );
  }

  Widget _buildStatsPanel(BuildContext context, TrackingState state, WidgetRef ref) {
    final isKm = ref.watch(isKmProvider);
    final distLabel = isKm ? 'KM' : 'MI';
    final distValue = isKm ? state.distanceKm : (state.distanceKm * 0.621371);
    final speedLabel = isKm ? 'km/h' : 'mph';
    final speedValue = isKm ? state.currentSpeed : (state.currentSpeed * 0.621371);
    final formattedSpeed = speedValue == 0 ? "0.0" : speedValue.toStringAsFixed(1);

    return GlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(context, 'TIME', state.formattedDuration),
          _statDivider(context),
          _buildStatItem(context, distLabel, distValue.toStringAsFixed(2), highlight: true),
          _statDivider(context),
          _buildStatItem(context, speedLabel, formattedSpeed),
          _statDivider(context),
          _buildStatItem(context, 'STEPS', state.currentSteps.toString()),
        ],
      ),
    );
  }

  Widget _statDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value,
      {bool highlight = false}) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 20,
              height: 1.0,
              color: highlight ? theme.colorScheme.primary : null,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    Key? key,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 80,
    double iconSize = 40,
    Color iconColor = Colors.black87,
    Color? borderColor,
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
          border: borderColor != null ? Border.all(color: borderColor, width: 1) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
  }

  Widget _buildHomeHeader(BuildContext context, TrackingState state) {
    final theme = Theme.of(context);
    final progressState = ref.watch(progressProvider);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(state.status),
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: GlassContainer(
                width: 48,
                height: 48,
                borderRadius: 24,
                padding: EdgeInsets.zero,
                child: ClipOval(
                  child: ref.watch(profileProvider).when(
                    data: (state) {
                      final gender = state.gender;
                      if (gender == 'Male') {
                        return Image.asset('assets/images/male_avatar.png', fit: BoxFit.cover);
                      } else if (gender == 'Female') {
                        return Image.asset('assets/images/female_avatar.png', fit: BoxFit.cover);
                      } else {
                        return Image.asset('assets/images/other_avatar.png', fit: BoxFit.cover);
                      }
                    },
                    loading: () => Icon(Icons.person_outline_rounded, color: theme.colorScheme.onSurface, size: 24),
                    error: (err, stack) => Icon(Icons.person_outline_rounded, color: theme.colorScheme.onSurface, size: 24),
                  ),
                ),
              ),
            ),
          ],
        ).animate().slideY(begin: -0.2).fadeIn(duration: 400.ms),

        const SizedBox(height: 64),

        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProgressScreen()),
            ).then((_) {
              ref.read(progressProvider.notifier).refresh();
            });
          },
          child: GlassContainer(
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.local_fire_department_rounded,
                    color: theme.colorScheme.primary, size: 30),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${progressState.currentStreak} Day Streak',
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
                    Text('Keep the momentum going',
                        style: theme.textTheme.bodyMedium?.copyWith(color: muted, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, color: muted, size: 28),
              ],
            ),
          ),
        ).animate().slideX(begin: 0.1, delay: 200.ms).fadeIn(delay: 200.ms),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _subtitle(TrackingStatus status) {
    switch (status) {
      case TrackingStatus.active:
        return 'Tracking in progress.';
      case TrackingStatus.paused:
        return 'Paused — resume anytime.';
      default:
        return 'Ready when you are.';
    }
  }
}
