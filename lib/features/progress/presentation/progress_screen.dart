import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:stride/theme/notebook_background.dart';
import 'package:stride/features/rewards/presentation/rewards_widgets.dart';
import 'package:stride/features/rewards/presentation/badges_screen.dart';
import 'package:stride/features/rewards/providers/rewards_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/core/providers/preferences_provider.dart';
import 'package:stride/core/utils/formatters.dart';
import 'package:stride/core/widgets/empty_state.dart';
import 'package:stride/core/widgets/screen_header.dart';
import 'package:stride/features/progress/providers/progress_provider.dart';
import 'package:stride/features/tracking/models/activity_model.dart';
import 'package:stride/features/tracking/presentation/run_summary_screen.dart';
import 'package:stride/theme/app_theme.dart';
import 'package:stride/theme/brutal_card.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(progressProvider);
    final isKm = ref.watch(isKmProvider);

    return Scaffold(
      body: NotebookBackground(
        seed: 6,
        child: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'progress'),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.activities.isEmpty
                        ? const EmptyState(
                            title: 'no runs yet',
                            subtitle: 'Moop is napping until your first run.\nTap start on the home screen.',
                          )
                        : _Body(state: state, isKm: isKm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final ProgressState state;
  final bool isKm;

  const _Body({required this.state, required this.isKm});

  double get _unit => isKm ? 1000 : kmPerMile * 1000;
  String get _unitLabel => isKm ? 'km' : 'mi';

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    final total = state.activities.fold<double>(0, (s, a) => s + a.distanceMeters) / _unit;
    final longest = state.longestRun;
    final fastest = state.fastest5k;

    Widget pair(Widget a, Widget b) => Row(
          children: [Expanded(child: a), const SizedBox(width: 6), Expanded(child: b)],
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 24),
      children: [
        Consumer(
          builder: (context, ref, _) => LevelCard(
            rewards: ref.watch(rewardsProvider),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BadgesScreen())),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _Metric(color: c.butter, value: total.toStringAsFixed(1), label: 'TOTAL ${_unitLabel.toUpperCase()}')),
            const SizedBox(width: 6),
            Expanded(child: _Metric(color: c.sky, value: '${state.activities.length}', label: 'RUNS')),
            const SizedBox(width: 6),
            Expanded(child: _Metric(color: c.blush, value: '${state.currentStreak}', label: 'STREAK')),
          ],
        ),
        const SizedBox(height: 6),
        pair(
          _Metric(
            color: c.sage,
            icon: Icons.emoji_events_rounded,
            value: longest == null ? '--' : '${(longest.distanceMeters / _unit).toStringAsFixed(2)} $_unitLabel',
            label: 'LONGEST RUN',
          ),
          _Metric(
            color: c.surface,
            icon: Icons.bolt_rounded,
            value: fastest == null ? '--' : '${formatPace(fastest.avgSpeedKmH, isKm: isKm)} /$_unitLabel',
            label: 'FASTEST 5K PACE',
          ),
        ),
        const SizedBox(height: 22),
        Text('RECENT RUNS (${_unitLabel.toUpperCase()})', style: text.labelSmall),
        const SizedBox(height: 8),
        BrutalCard(
          height: 190,
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
          child: _RecentChart(activities: state.activities, unitMeters: _unit),
        ),
        const SizedBox(height: 22),
        Text('HISTORY', style: text.labelSmall),
        const SizedBox(height: 8),
        for (final (i, a) in state.activities.indexed)
          _HistoryRow(activity: a, isKm: isKm, color: [c.butter, c.sky, c.blush, c.sage][i % 4]),
      ].animate(interval: 30.ms).fadeIn(duration: 250.ms),
    );
  }
}

class _Metric extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String value;
  final String label;

  const _Metric({required this.color, required this.value, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    final fg = color == c.surface ? c.ink : c.onPastel;
    return BrutalCard(
      color: color,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(height: 6),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: text.headlineMedium?.copyWith(color: fg)),
          ),
          const SizedBox(height: 4),
          Text(label, style: text.labelSmall?.copyWith(color: fg), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Last seven runs as outlined bars, newest on the right.
class _RecentChart extends StatelessWidget {
  final List<ActivityModel> activities;
  final double unitMeters;

  const _RecentChart({required this.activities, required this.unitMeters});

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    final recent = (List<ActivityModel>.from(activities)..sort((a, b) => a.startTime.compareTo(b.startTime)))
        .reversed
        .take(7)
        .toList()
        .reversed
        .toList();
    final values = recent.map((a) => a.distanceMeters / unitMeters).toList();
    final maxY = values.fold<double>(0, (m, v) => v > m ? v : m);

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 1 : maxY * 1.2,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              getTitlesWidget: (v, meta) => Text(values[v.toInt()].toStringAsFixed(1), style: text.labelSmall),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (v, meta) {
                final d = recent[v.toInt()].startTime;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${d.day}/${d.month}', style: text.labelSmall),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (final (i, v) in values.indexed)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: v,
                width: 22,
                color: i == values.length - 1 ? c.butter : c.go,
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: c.outline, width: 2),
              ),
            ]),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final ActivityModel activity;
  final bool isKm;
  final Color color;

  const _HistoryRow({required this.activity, required this.isKm, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final d = activity.startTime;
    final distance = activity.distanceMeters / (isKm ? 1000 : kmPerMile * 1000);

    return BrutalCard(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RunSummaryScreen(activity: activity)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: Brutal.box(c, color: color, radius: Brutal.radiusSmall, shadow: 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${d.day}', style: text.headlineSmall?.copyWith(color: c.onPastel, height: 1)),
                Text(months[d.month - 1], style: text.labelSmall?.copyWith(color: c.onPastel, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${distance.toStringAsFixed(2)} ${isKm ? 'km' : 'mi'}', style: text.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  '${formatDuration(activity.durationSeconds)} · ${formatPace(activity.avgSpeedKmH, isKm: isKm)} /${isKm ? 'km' : 'mi'}',
                  style: text.bodyMedium,
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: c.ink),
        ],
      ),
    );
  }
}
