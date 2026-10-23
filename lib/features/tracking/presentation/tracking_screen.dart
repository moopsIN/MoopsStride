import 'package:flutter/material.dart';
import 'package:stride/theme/notebook_background.dart';
import 'package:stride/features/rewards/domain/unlocks.dart';
import 'package:stride/features/rewards/data/run_rewards.dart';
import 'package:stride/features/rewards/domain/badges.dart';
import 'package:stride/features/rewards/domain/rewards_engine.dart';
import 'package:stride/features/rewards/presentation/badges_screen.dart';
import 'package:stride/features/rewards/providers/rewards_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:stride/features/tracking/providers/tracking_provider.dart';
import 'package:stride/theme/brutal_card.dart';
import 'package:stride/core/config/secrets.dart';
import 'package:stride/features/tracking/presentation/run_summary_screen.dart';
import 'package:stride/features/tracking/presentation/hold_to_confirm_button.dart';
import 'package:stride/core/providers/preferences_provider.dart';
import 'package:stride/core/utils/formatters.dart';
import 'package:stride/features/profile/presentation/profile_screen.dart';
import 'package:stride/features/progress/providers/progress_provider.dart';
import 'package:stride/features/progress/presentation/progress_screen.dart';
import 'package:stride/features/sync/providers/sync_engine.dart';
import 'package:stride/core/widgets/moop.dart';
import 'package:stride/theme/app_theme.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final MapController _mapController = MapController();

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Only reached once onboarded, so it's safe to pull here. Catches up on
    // runs recorded offline or on other devices, at start and on resume.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(syncEngineProvider).fullSync(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(progressProvider.notifier).refresh();
      ref.read(syncEngineProvider).fullSync();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _finishRun() async {
    final notifier = ref.read(trackingProvider.notifier);
    final activity = await notifier.stopTracking();
    if (!mounted) return;

    if (TrackingNotifier.isTooShort(activity) && !await _confirmSaveShortRun()) {
      notifier.reset();
      return;
    }

    // Rewards must never cost a run: if anything in the rewards step fails,
    // the run is still saved and there's simply no celebration.
    var saved = false;
    var unlocks = Unlocks.none;
    try {
      unlocks = await saveRunAndCollectUnlocks(
        run: activity,
        save: () async {
          await notifier.saveActivity(activity);
          saved = true;
        },
        store: ref.read(rewardsSeenStoreProvider),
      );
    } catch (e) {
      debugPrint('Rewards step failed: $e');
      if (!saved) await notifier.saveActivity(activity);
    }
    ref.read(progressProvider.notifier).refresh();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RunSummaryScreen(activity: activity, unlocks: unlocks),
      ),
    );

    if (!mounted) return;
    ref.read(trackingProvider.notifier).reset();
  }

  /// Returns true to save anyway.
  Future<bool> _confirmSaveShortRun() async {
    final save = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Very Short Run'),
        content: const Text(
            'This run is under 50 m or 30 seconds. It may have been started by accident.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Discard')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save Anyway')),
        ],
      ),
    );
    return save == true;
  }

  static const double _idleZoom = 18.0;
  static const double _activeZoom = 19.5;
  bool _hasZoomedForActiveRun = false;
  bool _isMapReady = false;
  bool _centeredOnUser = false;
  /// Bumped when "start run" is tapped so Moop cheers.
  int _startCheer = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingProvider);

    ref.listen<TrackingState>(trackingProvider, (previous, next) {
      final message = next.errorMessage;
      if (message != null) {
        ref.read(trackingProvider.notifier).clearError();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    });

    // Follow the runner while active; recentre once per run so the user can
    // still pinch-zoom without it snapping back.
    if (state.currentLocation != null && _isMapReady) {
      if (state.status == TrackingStatus.active) {
        final targetZoom = _hasZoomedForActiveRun ? _mapController.camera.zoom : _activeZoom;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _mapController.move(state.currentLocation!, targetZoom);
        });
        _hasZoomedForActiveRun = true;
      } else if (state.status == TrackingStatus.notStarted) {
        _hasZoomedForActiveRun = false;
        // The map is built before the first GPS fix (centred on 0,0, i.e.
        // open ocean); bring it to the user once a fix arrives.
        if (!_centeredOnUser) {
          _centeredOnUser = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _mapController.move(state.currentLocation!, _idleZoom);
          });
        }
      }
    }

    final hasStarted = state.status != TrackingStatus.notStarted;

    return Scaffold(
      body: NotebookBackground(
        seed: 4,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                hasStarted ? _buildRunHeader(context, state) : _buildHomeHeader(context),
                const SizedBox(height: 16),
                Expanded(child: _buildMapCard(context, state)),
                // Extra room when idle for Moop perched on the start button.
                SizedBox(height: hasStarted ? 14 : 40),
                // Idle: "start run" sits right under the map, the easiest
                // thing to reach, with the info blocks below it so stray taps
                // near the bottom edge land on them, not on start.
                // Running: live stats above, pause/finish at the bottom.
                if (hasStarted) ...[
                  _buildRunStats(context, state),
                  const SizedBox(height: 18),
                  _buildControls(context, state),
                ] else ...[
                  _buildControls(context, state),
                  const SizedBox(height: 14),
                  _buildHomeBlocks(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- header

  Widget _buildHomeHeader(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(), style: text.headlineLarge),
              const SizedBox(height: 6),
              _LevelChip(rewards: ref.watch(rewardsProvider)),
            ],
          ),
        ),
        BrutalCard(
          width: 52,
          height: 52,
          borderRadius: 26,
          color: c.sage,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: Center(child: Moop(size: 36, animate: false, growth: ref.watch(rewardsProvider).moopGrowth)),
        ),
      ],
    );
  }

  Widget _buildRunHeader(BuildContext context, TrackingState state) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    final active = state.status == TrackingStatus.active;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BrutalPill(
                text: active ? 'RUNNING' : 'PAUSED',
                color: active ? c.go : c.pause,
                icon: active ? Icons.circle : Icons.pause_rounded,
              ),
              const SizedBox(height: 8),
              Text(
                state.formattedDuration,
                style: text.displayLarge?.copyWith(fontSize: 48, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
        Moop(size: 64, running: active, mood: active ? MoopMood.idle : MoopMood.sleepy),
      ],
    );
  }

  // ------------------------------------------------------------------- map

  Widget _buildMapCard(BuildContext context, TrackingState state) {
    final c = context.stride;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mapStyle = dark ? 'dataviz-dark' : 'dataviz';
    final here = state.currentLocation;

    return BrutalCard(
      padding: EdgeInsets.zero,
      color: c.surfaceAlt,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Brutal.radius - Brutal.outline),
        child: Stack(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: _isMapReady ? 1 : 0,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: here ?? const LatLng(0, 0),
                  initialZoom: _idleZoom,
                  onMapReady: () {
                    if (mounted) setState(() => _isMapReady = true);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://api.maptiler.com/maps/$mapStyle/{z}/{x}/{y}.png?key=${Secrets.mapTilerKey}',
                    userAgentPackageName: 'com.moops.stride',
                  ),
                  if (state.routePoints.length > 1)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: state.routePoints,
                        color: c.outline,
                        strokeWidth: 9,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                      Polyline(
                        points: state.routePoints,
                        color: c.go,
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    ]),
                  if (here != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: here,
                        width: 26,
                        height: 26,
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.coral,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.outline, width: Brutal.outline),
                          ),
                        ),
                      ),
                    ]),
                  const RichAttributionWidget(
                    attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
                  ),
                ],
              ),
            ),
            if (here == null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Moop(size: 72, mood: MoopMood.sleepy),
                    const SizedBox(height: 8),
                    Text('finding you…', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------- info blocks

  Widget _buildHomeBlocks(BuildContext context) {
    final c = context.stride;
    final progress = ref.watch(progressProvider);
    void openProgress() => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProgressScreen()))
        .then((_) => ref.read(progressProvider.notifier).refresh());

    return Row(
      children: [
        Expanded(
          child: _InfoBlock(
            color: c.butter,
            icon: Icons.local_fire_department_rounded,
            value: '${progress.currentStreak}',
            label: progress.currentStreak == 1 ? 'DAY STREAK' : 'DAYS STREAK',
            onTap: openProgress,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _InfoBlock(
            color: c.sky,
            icon: Icons.calendar_today_rounded,
            value: _weekDistance(progress),
            label: _weekRuns(progress),
            onTap: openProgress,
          ),
        ),
      ],
    );
  }

  Widget _buildRunStats(BuildContext context, TrackingState state) {
    final c = context.stride;
    final isKm = ref.watch(isKmProvider);
    final distance = state.distanceKm * (isKm ? 1 : 1 / kmPerMile);
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _InfoBlock(
              color: c.sky,
              value: distance.toStringAsFixed(2),
              label: isKm ? 'KILOMETRES' : 'MILES',
              big: true,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _InfoBlock(
                    color: c.blush,
                    value: formatPace(state.currentSpeed, isKm: isKm),
                    label: isKm ? 'PACE /KM' : 'PACE /MI',
                    compact: true,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _InfoBlock(
                    color: c.sage,
                    value: '${state.currentSteps}',
                    label: 'STEPS',
                    compact: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- controls

  /// Idle: START. Running: only PAUSE, so nothing destructive is one tap
  /// away. Paused: hold-to-finish next to RESUME.
  Widget _buildControls(BuildContext context, TrackingState state) {
    final c = context.stride;
    final notifier = ref.read(trackingProvider.notifier);

    switch (state.status) {
      case TrackingStatus.active:
        return _BigButton(
          label: 'pause',
          icon: Icons.pause_rounded,
          color: c.pause,
          onTap: () {
            HapticFeedback.lightImpact();
            notifier.pauseTracking();
          },
        );
      case TrackingStatus.paused:
        return Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HoldToConfirmButton(
                  icon: Icons.stop_rounded,
                  color: c.stop,
                  iconColor: textOn(c.stop),
                  size: 62,
                  onConfirmed: _finishRun,
                ),
                const SizedBox(height: 4),
                Text('HOLD TO FINISH', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _BigButton(
                label: 'resume',
                icon: Icons.play_arrow_rounded,
                color: c.go,
                onTap: () {
                  HapticFeedback.lightImpact();
                  notifier.resumeTracking();
                },
              ),
            ),
          ],
        );
      default:
        // Moop sits on the start button's right end, feet on its top edge:
        // waves hello now and then, cheers when the run is started. It
        // ignores touches so taps reach the button and map underneath.
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _BigButton(
              label: 'start run',
              icon: Icons.directions_run_rounded,
              color: c.go,
              onTap: () async {
                setState(() => _startCheer++);
                final ok = await notifier.startTracking();
                if (ok) {
                  HapticFeedback.mediumImpact();
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Turn on location and allow access to track your run.'),
                  ));
                }
              },
            ),
            Positioned(
              right: 26,
              top: -46,
              child: IgnorePointer(
                child: Moop(
                  size: 56,
                  greet: true,
                  idleWave: const Duration(seconds: 8),
                  reaction: MoopReaction.cheer,
                  reactionTick: _startCheer,
                  growth: ref.watch(rewardsProvider).moopGrowth,
                ),
              ),
            ),
          ],
        );
    }
  }

  // ---------------------------------------------------------------- helpers

  String _weekDistance(ProgressState progress) {
    final isKm = ref.watch(isKmProvider);
    final d = progress.weekDistanceMeters / (isKm ? 1000 : kmPerMile * 1000);
    return '${d.toStringAsFixed(1)} ${isKm ? 'km' : 'mi'}';
  }

  String _weekRuns(ProgressState progress) => switch (progress.weekRuns) {
        0 => 'THIS WEEK',
        1 => 'THIS WEEK · 1 RUN',
        final n => 'THIS WEEK · $n RUNS',
      };

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'good morning';
    if (hour < 17) return 'good afternoon';
    return 'good evening';
  }
}

/// Level and badge count; opens the badges screen.
class _LevelChip extends StatelessWidget {
  final RewardsSnapshot rewards;
  const _LevelChip({required this.rewards});

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    return BrutalCard(
      shadow: 3,
      borderRadius: Brutal.radiusPill,
      color: c.butter,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BadgesScreen())),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.military_tech_rounded, size: 16, color: c.onPastel),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'LEVEL ${rewards.level} · ${rewards.earned.length}/${BadgeId.values.length} BADGES',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.onPastel),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded, size: 16, color: c.onPastel),
        ],
      ),
    );
  }
}

/// A pastel stat block: big value, small mono label.
class _InfoBlock extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String value;
  final String label;
  final bool big;
  final bool compact;
  final VoidCallback? onTap;

  const _InfoBlock({
    required this.color,
    required this.value,
    required this.label,
    this.icon,
    this.big = false,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final valueSize = big ? 46.0 : (compact ? 22.0 : 30.0);
    return BrutalCard(
      color: color,
      onTap: onTap,
      // Big and compact blocks fill the space their parent row gives them.
      height: big || compact ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 8 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: big || compact ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: textOn(color)),
            const SizedBox(height: 6),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: text.displayLarge?.copyWith(
                fontSize: valueSize,
                color: textOn(color),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: text.labelSmall?.copyWith(color: textOn(color)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// The main action: tall, full-width, unmistakable.
class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BigButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      color: color,
      height: 72,
      borderRadius: 36,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: textOn(color)),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: textOn(color)),
          ),
        ],
      ),
    );
  }
}
