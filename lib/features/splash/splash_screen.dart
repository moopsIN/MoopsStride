import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/features/auth/presentation/auth_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/features/auth/providers/auth_provider.dart';
import 'package:stride/features/home/presentation/home_screen.dart';
import 'package:stride/features/onboarding/presentation/onboarding_screen.dart';
import 'package:stride/core/database/local_db.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simulate some loading time (e.g. database init, auth check)
    // In future phases we will navigate based on Auth state.
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      
      final db = await LocalDatabase.instance.database;
      final profiles = await db.query('user_profile');
      final hasCompletedOnboarding = profiles.isNotEmpty;
      
      if (!mounted) return;

      final user = ref.read(authProvider);
      
      Widget nextScreen;
      if (hasCompletedOnboarding) {
        nextScreen = const HomeScreen();
      } else if (user != null) {
        nextScreen = const OnboardingScreen();
      } else {
        nextScreen = const AuthScreen();
      }
      
      Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoAsset = isDark ? 'assets/images/moops-logo-dark.png' : 'assets/images/moops-logo-light.png';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              const Spacer(),
            // Abstract Path/Stride Logo placeholder
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Icon(
                Icons.directions_run_rounded,
                size: 48,
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            )
                .animate()
                .scale(duration: 800.ms, curve: Curves.easeOutBack)
                .fadeIn(duration: 800.ms),
            
            const SizedBox(height: 24),
            
            // Brand Name
            Text(
              'Stride by Moops',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 32,
                  ),
            )
                .animate()
                .fadeIn(delay: 400.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0, delay: 400.ms, duration: 600.ms, curve: Curves.easeOut),
            
            const SizedBox(height: 8),
            
            // Tagline
            Text(
              'Every step, beautifully tracked.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
            )
                .animate()
                .fadeIn(delay: 800.ms, duration: 600.ms),
                
            const Spacer(),
            
            // Bottom Logo
            Image.asset(
              logoAsset,
              height: 48,
            ).animate().fadeIn(delay: 1000.ms),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
  }
}


