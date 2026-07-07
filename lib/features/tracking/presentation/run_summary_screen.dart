import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/core/config/secrets.dart';
import 'package:stride/features/tracking/models/activity_model.dart';
import 'package:stride/theme/glass_container.dart';

class RunSummaryScreen extends StatelessWidget {
  final ActivityModel activity;

  const RunSummaryScreen({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    final hasRoute = activity.routePoints.isNotEmpty;

    LatLngBounds? bounds;
    if (activity.routePoints.length > 1) {
      bounds = LatLngBounds.fromPoints(activity.routePoints);
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Bright map (or a themed placeholder if no route was recorded)
          Positioned.fill(
            child: hasRoute ? _buildMap(context, bounds) : _buildNoRoute(context),
          ),

          // 2. Theme-matched overlay: transparent over the top so the map stays
          //    bright, solidifying into the background where the stats sit. Uses
          //    the scaffold background so it's correct in both light and dark.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [bg, bg, bg.withValues(alpha: 0.0)],
                    stops: const [0.0, 0.34, 0.66],
                  ),
                ),
              ),
            ),
          ),

          // 3. Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _GlassIconButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ).animate().fadeIn(duration: 400.ms),
                    ],
                  ),

                  const Spacer(),

                  _buildHeader(context)
                      .animate()
                      .slideY(begin: 0.25, curve: Curves.easeOut)
                      .fadeIn(delay: 150.ms, duration: 450.ms),

                  const SizedBox(height: 22),

                  _buildStatsGrid(context),

                  const SizedBox(height: 24),

                  _buildDoneButton(context),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context, LatLngBounds? bounds) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: bounds != null
            ? CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.only(
                  top: 120,
                  left: 60,
                  right: 60,
                  bottom: 360,
                ),
              )
            : null,
        initialCenter: activity.routePoints.first,
        initialZoom: 15.0,
        minZoom: 10.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=${Secrets.mapTilerKey}',
          userAgentPackageName: 'com.moops.stride',
        ),
        PolylineLayer(
          polylines: [
            // Soft dark halo so the route reads clearly on the bright map.
            Polyline(
              points: activity.routePoints,
              color: Colors.black.withValues(alpha: 0.18),
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
            ),
            Polyline(
              points: activity.routePoints,
              color: accent,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: activity.routePoints.first,
              width: 22,
              height: 22,
              child: const _RouteDot(color: Color(0xFF2ECC71)),
            ),
            Marker(
              point: activity.routePoints.last,
              width: 22,
              height: 22,
              child: _RouteDot(color: accent),
            ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('© OpenStreetMap contributors'),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 700.ms);
  }

  Widget _buildNoRoute(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined,
              size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            'No route recorded',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final distanceKm = (activity.distanceMeters / 1000).toStringAsFixed(2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              activity.type.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            Text(
              '  ·  ${_formatDate(activity.startTime)}',
              style: theme.textTheme.labelMedium?.copyWith(color: muted, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              distanceKm,
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 62,
                height: 1.0,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'KM',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatTile(context, Icons.schedule_rounded, 'TIME',
                  _formatDuration(activity.durationSeconds), 300),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildStatTile(context, Icons.speed_rounded, 'AVG PACE',
                  _formatPace(activity.avgPace), 380),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildStatTile(context, Icons.local_fire_department_rounded,
                  'CALORIES', activity.caloriesEstimate.toStringAsFixed(0), 460),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildStatTile(context, Icons.directions_walk_rounded, 'STEPS',
                  activity.steps.toString(), 540),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatTile(
      BuildContext context, IconData icon, String label, String value, int delayMs) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 7),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.displayLarge?.copyWith(fontSize: 26, height: 1.0),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.2, curve: Curves.easeOut).fadeIn(delay: delayMs.ms);
  }

  Widget _buildDoneButton(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: theme.colorScheme.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        child: Text(
          'DONE',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.scaffoldBackgroundColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.5,
          ),
        ),
      ),
    ).animate().slideY(begin: 0.4, delay: 640.ms, curve: Curves.easeOutBack).fadeIn(delay: 640.ms);
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

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  ·  $hour12:$minute $ampm';
  }
}

/// A start/finish marker: a filled dot with a white ring so it reads on any map tile.
class _RouteDot extends StatelessWidget {
  final Color color;
  const _RouteDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8, spreadRadius: 1),
        ],
      ),
    );
  }
}

/// A circular glass button, legible over the bright map in either theme.
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        width: 44,
        height: 44,
        borderRadius: 22,
        padding: EdgeInsets.zero,
        child: Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}
