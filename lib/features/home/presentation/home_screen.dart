import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:stride/theme/glass_container.dart';
import 'package:stride/features/tracking/presentation/tracking_screen.dart';
import 'package:stride/features/profile/presentation/profile_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/features/progress/providers/progress_provider.dart';
import 'package:stride/features/progress/presentation/progress_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(progressProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final progressState = ref.watch(progressProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
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
              ),
            ).animate().slideY(begin: -0.2).fadeIn(duration: 400.ms),

            // Streak Indicator Placeholder
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: GlassContainer(
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
                  ],
                ),
              ),
            ).animate().slideX(begin: 0.1, delay: 200.ms).fadeIn(delay: 200.ms),

            const Spacer(),

            // Start CTA
            Padding(
              padding: const EdgeInsets.all(48.0),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const TrackingScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'start_run_button',
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'START',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                color: Theme.of(context).colorScheme.background,
                                fontSize: 32,
                                letterSpacing: 2,
                              ),
                        ),
                      ),
                    ),
                  ),
                ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                 .scaleXY(begin: 1.0, end: 1.05, duration: 1.seconds, curve: Curves.easeInOut),
              ),
            ),
            
            // View Progress Button
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProgressScreen()),
                  ).then((_) {
                    ref.read(progressProvider.notifier).refresh();
                  });
                },
                icon: const Icon(Icons.bar_chart, color: Colors.white70),
                label: Text(
                  'VIEW PROGRESS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 2, color: Colors.white70),
                ),
              ),
            ).animate().slideY(begin: 0.2, delay: 400.ms).fadeIn(delay: 400.ms),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
