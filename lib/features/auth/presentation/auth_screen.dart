import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/core/widgets/primary_button.dart';
import 'package:stride/features/onboarding/presentation/onboarding_screen.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/home/presentation/home_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/features/auth/providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;

  void _handleGuestLogin() {
    _routeAfterLogin();
  }

  Future<void> _routeAfterLogin() async {
    final db = await LocalDatabase.instance.database;
    final profiles = await db.query('user_profile');
    if (!mounted) return;
    
    if (profiles.isNotEmpty) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      if (_isLogin) {
        await ref.read(authProvider.notifier).signInWithEmail(email, password);
      } else {
        await ref.read(authProvider.notifier).signUpWithEmail(email, password);
      }
      if (mounted) {
        await _routeAfterLogin();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      if (mounted) {
        await _routeAfterLogin();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Icon(
                Icons.directions_run_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ).animate().scale(duration: 500.ms).fadeIn(),
              const SizedBox(height: 24),
              Text(
                'Welcome to Stride by Moops',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                'Sign in to sync your runs or continue as a guest offline.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 48),
              
              // Email / Password Form
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.emailAddress,
              ).animate().slideX(begin: 0.1, delay: 400.ms).fadeIn(delay: 400.ms),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                obscureText: true,
              ).animate().slideX(begin: 0.1, delay: 500.ms).fadeIn(delay: 500.ms),
              const SizedBox(height: 24),
              
              PrimaryButton(
                text: _isLogin ? 'Sign In' : 'Sign Up',
                isLoading: _isLoading,
                onPressed: _handleEmailAuth,
              ).animate().slideY(begin: 0.2, delay: 600.ms).fadeIn(delay: 600.ms),
              
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? "Don't have an account? Sign Up" : 'Already have an account? Sign In'),
              ).animate().fadeIn(delay: 650.ms),
              
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: Theme.of(context).colorScheme.surface)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR'),
                  ),
                  Expanded(child: Divider(color: Theme.of(context).colorScheme.surface)),
                ],
              ).animate().fadeIn(delay: 700.ms),
              const SizedBox(height: 24),
              
              // Social Mocks
              OutlinedButton.icon(
                onPressed: _handleGoogleLogin,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ).animate().slideY(begin: 0.2, delay: 800.ms).fadeIn(delay: 800.ms),
              const SizedBox(height: 16),
              
              // Guest CTA
              TextButton(
                onPressed: _handleGuestLogin,
                child: const Text('Continue as Guest'),
              ).animate().fadeIn(delay: 1000.ms),
              const SizedBox(height: 48),
              
              // Bottom Logo
              Center(
                child: Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/images/moops-logo-dark.png'
                      : 'assets/images/moops-logo-light.png',
                  height: 72,
                ).animate().fadeIn(delay: 1200.ms),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
