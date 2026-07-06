import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/theme/glass_container.dart';
import 'package:stride/features/progress/providers/progress_provider.dart';
import 'package:stride/features/tracking/models/activity_model.dart';
import 'package:stride/features/tracking/presentation/run_summary_screen.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Progress'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.activities.isEmpty
              ? _buildEmptyState(context)
              : _buildBody(context, state),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_run, size: 80, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 24),
          Text(
            'No runs yet!',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'Go out and track your first activity.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildBody(BuildContext context, ProgressState state) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // PRs
                Row(
                  children: [
                    Expanded(
                      child: _buildPRCard(
                        context, 
                        'Longest Run', 
                        state.longestRun != null ? '${(state.longestRun!.distanceMeters / 1000).toStringAsFixed(2)} km' : '--',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPRCard(
                        context, 
                        'Fastest 5K', 
                        state.fastest5k != null ? _formatPace(state.fastest5k!.avgPace) : '--',
                      ),
                    ),
                  ],
                ).animate().slideY(begin: 0.2).fadeIn(duration: 400.ms),

                const SizedBox(height: 32),
                
                // Chart
                Text('Recent Distances (km)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: _buildChart(context, state.activities),
                  ),
                ).animate().slideY(begin: 0.2).fadeIn(delay: 150.ms),

                const SizedBox(height: 32),
                
                Text('Activity History', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final activity = state.activities[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => RunSummaryScreen(activity: activity),
                      ));
                    },
                    child: GlassContainer(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDate(activity.startTime),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(activity.distanceMeters / 1000).toStringAsFixed(2)} km',
                                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 20),
                              ),
                            ],
                          ),
                          Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ),
                  ).animate().slideX(begin: 0.1).fadeIn(delay: Duration(milliseconds: 200 + (index * 50))),
                );
              },
              childCount: state.activities.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPRCard(BuildContext context, String title, String value) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24)),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<ActivityModel> activities) {
    if (activities.length < 2) {
      return Center(
        child: Text('More data needed for chart', style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    final sorted = List<ActivityModel>.from(activities)..sort((a, b) => a.startTime.compareTo(b.startTime));
    final latest = sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;

    final spots = latest.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.distanceMeters / 1000.0);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPace(double paceMinPerKm) {
    if (paceMinPerKm == 0) return "--:--";
    final minutes = paceMinPerKm.truncate();
    final seconds = ((paceMinPerKm - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0 && now.day == date.day) {
      return 'Today, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1 || (difference.inDays == 0 && now.day != date.day)) {
      return 'Yesterday, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}/${date.day}/${date.year}';
  }
}
