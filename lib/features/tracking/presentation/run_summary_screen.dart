import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:stride/features/rewards/presentation/celebration_sheet.dart';
import 'package:stride/features/rewards/domain/unlocks.dart';
import 'package:stride/features/rewards/providers/rewards_provider.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stride/core/config/secrets.dart';
import 'package:stride/core/providers/preferences_provider.dart';
import 'package:stride/core/utils/formatters.dart';
import 'package:stride/core/widgets/moop.dart';
import 'package:stride/features/progress/providers/progress_provider.dart';
import 'package:stride/features/tracking/models/activity_model.dart';
import 'package:stride/theme/app_theme.dart';
import 'package:stride/theme/brutal_card.dart';

/// A finished run as a shareable card: framed route map, headline distance,
/// pastel stat tiles and splits.
class RunSummaryScreen extends ConsumerStatefulWidget {
  final ActivityModel activity;
  /// What this run unlocked; celebrated once when the summary opens.
  final Unlocks unlocks;

  const RunSummaryScreen({super.key, required this.activity, this.unlocks = Unlocks.none});

  @override
  ConsumerState<RunSummaryScreen> createState() => _RunSummaryScreenState();
}

class _RunSummaryScreenState extends ConsumerState<RunSummaryScreen> {
  final GlobalKey _shareKey = GlobalKey();
  bool _isSharing = false;
  /// True while the share image is rendered, so buttons stay out of it.
  bool _isCapturing = false;

  ActivityModel get activity => widget.activity;

  @override
  void initState() {
    super.initState();
    if (!widget.unlocks.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showCelebration(context, widget.unlocks);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                child: RepaintBoundary(
                  key: _shareKey,
                  child: Container(
                    // Solid ground so the shared image isn't transparent.
                    color: c.background,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMapCard(context),
                        const SizedBox(height: 18),
                        _buildHeadline(context)
                            .animate()
                            .fadeIn(duration: 350.ms)
                            .slideY(begin: 0.15, curve: Curves.easeOut),
                        const SizedBox(height: 16),
                        _buildStatsGrid(context),
                        if (activity.splits.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _buildSplits(context),
                        ],
                        if (_isCapturing) ...[
                          const SizedBox(height: 14),
                          Text('tracked with stride · by moops',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
              child: _buildActions(context),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- map

  Widget _buildMapCard(BuildContext context) {
    final c = context.stride;
    final points = activity.routePoints;
    return BrutalCard(
      height: 250,
      padding: EdgeInsets.zero,
      color: c.surfaceAlt,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Brutal.radius - Brutal.outline),
        child: Stack(
          children: [
            Positioned.fill(
              child: points.isEmpty ? _buildNoRoute(context) : _buildMap(context),
            ),
            if (!_isCapturing)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    _CircleButton(icon: Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
                    const Spacer(),
                    _isSharing
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                          )
                        : _CircleButton(icon: Icons.ios_share_rounded, onTap: _shareRun),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final c = context.stride;
    final points = activity.routePoints;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: points.length > 1
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(points),
                padding: const EdgeInsets.fromLTRB(40, 64, 40, 32),
              )
            : null,
        initialCenter: points.first,
        initialZoom: 15,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://api.maptiler.com/maps/${dark ? 'dataviz-dark' : 'dataviz'}/{z}/{x}/{y}.png?key=${Secrets.mapTilerKey}',
          userAgentPackageName: 'com.moops.stride',
        ),
        PolylineLayer(polylines: [
          Polyline(points: points, color: c.outline, strokeWidth: 9, strokeCap: StrokeCap.round, strokeJoin: StrokeJoin.round),
          Polyline(points: points, color: c.go, strokeWidth: 5, strokeCap: StrokeCap.round, strokeJoin: StrokeJoin.round),
        ]),
        MarkerLayer(markers: [
          Marker(point: points.first, width: 22, height: 22, child: _RouteDot(color: c.go)),
          Marker(point: points.last, width: 22, height: 22, child: _RouteDot(color: c.coral)),
        ]),
        const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
      ],
    );
  }

  Widget _buildNoRoute(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Moop(size: 64, mood: MoopMood.sleepy, animate: false),
          const SizedBox(height: 8),
          Text('no route recorded', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- headline

  Widget _buildHeadline(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    final isKm = ref.watch(isKmProvider);
    final distance = activity.distanceMeters / (isKm ? 1000 : kmPerMile * 1000);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${activity.type.toUpperCase()} · ${_formatDate(activity.startTime)}',
                style: text.labelSmall,
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        distance.toStringAsFixed(2),
                        style: text.displayLarge?.copyWith(fontSize: 64, height: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BrutalPill(text: isKm ? 'KM' : 'MI', color: c.butter),
                ],
              ),
            ],
          ),
        ),
        Moop(size: 76, mood: MoopMood.excited, growth: ref.watch(rewardsProvider).moopGrowth),
      ],
    );
  }

  // ----------------------------------------------------------------- stats

  Widget _buildStatsGrid(BuildContext context) {
    final c = context.stride;
    final isKm = ref.watch(isKmProvider);
    Widget row(Widget a, Widget b) => Row(
          children: [Expanded(child: a), const SizedBox(width: 6), Expanded(child: b)],
        );
    return Column(
      children: [
        row(
          _StatTile(color: c.butter, icon: Icons.schedule_rounded, label: 'TIME', value: formatDuration(activity.durationSeconds)),
          _StatTile(
            color: c.blush,
            icon: Icons.speed_rounded,
            label: isKm ? 'AVG PACE /KM' : 'AVG PACE /MI',
            value: formatPace(activity.avgSpeedKmH, isKm: isKm),
          ),
        ),
        const SizedBox(height: 6),
        row(
          _StatTile(
            color: c.sky,
            icon: Icons.local_fire_department_rounded,
            label: 'CALORIES',
            value: activity.caloriesEstimate.toStringAsFixed(0),
          ),
          _StatTile(color: c.sage, icon: Icons.directions_walk_rounded, label: 'STEPS', value: '${activity.steps}'),
        ),
      ].animate(interval: 60.ms).fadeIn(duration: 300.ms).slideY(begin: 0.2, curve: Curves.easeOut),
    );
  }

  /// Splits keep the unit they were recorded in, whatever the current setting.
  Widget _buildSplits(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    final unit = activity.splitUnitMeters;
    final unitLabel = unit < 1500 ? 'KM' : 'MI';
    final splits = activity.splits;

    // Only full splits compete for fastest; a short remainder is too noisy.
    int? fastest;
    for (var i = 0; i < splits.length; i++) {
      if (splits[i].distanceMeters < unit) continue;
      if (fastest == null || splits[i].durationSeconds < splits[fastest].durationSeconds) {
        fastest = i;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SPLITS', style: text.labelSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: splits.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (context, i) {
              final split = splits[i];
              final isFull = split.distanceMeters >= unit;
              final isFastest = i == fastest && splits.length > 1;
              final label = isFull
                  ? '$unitLabel ${i + 1}'
                  : '${(split.distanceMeters / unit).toStringAsFixed(2)} $unitLabel';
              final pace = split.paceSecondsPer(unit).round();
              return BrutalCard(
                color: isFastest ? c.butter : c.surface,
                shadow: 3,
                borderRadius: Brutal.radiusSmall,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: text.labelSmall?.copyWith(color: c.onPastel)),
                        if (isFastest) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.star_rounded, size: 13, color: c.onPastel),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pace ~/ 60}\'${(pace % 60).toString().padLeft(2, '0')}"',
                      style: text.headlineSmall?.copyWith(color: c.onPastel),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- actions

  Widget _buildActions(BuildContext context) {
    final c = context.stride;
    return Row(
      children: [
        BrutalCard(
          width: 58,
          height: 58,
          borderRadius: Brutal.radiusSmall,
          color: c.surface,
          onTap: () => _deleteWithUndo(context),
          child: Icon(Icons.delete_outline_rounded, color: c.ink, size: 26),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: BrutalCard(
            height: 58,
            borderRadius: Brutal.radiusSmall,
            color: c.brand,
            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: Center(
              child: Text(
                'done',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: c.onBrand),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _shareRun() async {
    if (_isSharing || _isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      // Let the frame without buttons (and with the footer) paint first.
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isSharing = true;
        });
      }
      if (pngBytes == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/stride_run_summary.png');
      await file.writeAsBytes(pngBytes);

      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: 'Check out my run on Stride by Moops!');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to share run.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isSharing = false;
        });
      }
    }
  }

  /// Deletes straight away and offers Undo, instead of a confirm dialog.
  /// The delete only syncs once the snackbar closes without Undo.
  Future<void> _deleteWithUndo(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final progress = ref.read(progressProvider.notifier);
    final id = activity.id;

    await progress.deleteActivity(id);
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);

    messenger.clearSnackBars();
    messenger
        .showSnackBar(SnackBar(
          content: const Text('Run deleted'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              if (!await progress.undoDelete(id)) {
                messenger.showSnackBar(const SnackBar(content: Text("Couldn't restore that run.")));
              }
            },
          ),
        ))
        .closed
        .then((reason) {
      if (reason != SnackBarClosedReason.action) progress.commitDeletes();
    });
  }

  String _formatDate(DateTime dt) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour12:$minute $ampm';
  }
}

class _StatTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({required this.color, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    return BrutalCard(
      color: color,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: c.onPastel),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label, style: text.labelSmall?.copyWith(color: c.onPastel), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: text.displaySmall?.copyWith(color: c.onPastel)),
          ),
        ],
      ),
    );
  }
}

/// Start/finish marker: a filled dot with an ink ring, readable on any tile.
class _RouteDot extends StatelessWidget {
  final Color color;
  const _RouteDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: context.stride.outline, width: Brutal.outline),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    return BrutalCard(
      width: 44,
      height: 44,
      borderRadius: 22,
      shadow: 3,
      color: c.surface,
      onTap: onTap,
      child: Icon(icon, size: 22, color: c.ink),
    );
  }
}
