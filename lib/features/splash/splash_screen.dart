import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/theme/app_theme.dart';
import 'package:stride/features/auth/presentation/auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simulate some loading time (e.g. database init, auth check)
    // In future phases we will navigate based on Auth state.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Abstract Path/Stride Logo placeholder
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accentColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: const Icon(
                Icons.directions_run_rounded,
                size: 48,
                color: AppTheme.backgroundDark,
              ),
            )
                .animate()
                .scale(duration: 800.ms, curve: Curves.easeOutBack)
                .fadeIn(duration: 800.ms),
            
            const SizedBox(height: 24),
            
            // Brand Name
            Text(
              'Moops Stride',
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
          ],
        ),
      ),
    );
  }
}


