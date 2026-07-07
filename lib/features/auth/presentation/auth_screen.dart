import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/core/widgets/primary_button.dart';
import 'package:stride/features/onboarding/presentation/onboarding_screen.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/tracking/presentation/tracking_screen.dart';
import 'package:stride/features/sync/presentation/sync_prompt_screen.dart';
import 'package:stride/features/sync/providers/sync_engine.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/features/auth/providers/auth_provider.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

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

  String _getErrorMessage(Object e) {
    if (e is FirebaseAuthException) {
      return e.message ?? 'Authentication failed.';
    }
    if (e is PlatformException) {
      return e.message ?? 'An unexpected platform error occurred.';
    }
    final msg = e.toString();
    if (msg.startsWith('Exception: ')) {
      return msg.substring(11);
    }
    return msg;
  }

  void _handleGuestLogin() {
    _routeAfterLogin();
  }

  Future<void> _routeAfterLogin() async {
    final db = await LocalDatabase.instance.database;
    final profiles = await db.query('user_profile');
    
    if (profiles.isNotEmpty) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TrackingScreen()),
        );
      }
    } else {
      final user = ref.read(authProvider);
      bool hasCloudData = false;
      
      if (user != null) {
        hasCloudData = await ref.read(syncEngineProvider).checkCloudDataExists(user.uid);
      }
      
      if (!mounted) return;
      
      if (hasCloudData) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SyncPromptScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    }
  }

  Future<void> _handleEmailAuth(StateSetter setSheetState) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    setSheetState(() => _isLoading = true);
    
    try {
      if (_isLogin) {
        await ref.read(authProvider.notifier).signInWithEmail(email, password);
      } else {
        await ref.read(authProvider.notifier).signUpWithEmail(email, password);
      }
      if (mounted) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop(); // Close sheet
        await _routeAfterLogin();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_getErrorMessage(e)),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) {
        setSheetState(() => _isLoading = false);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_getErrorMessage(e)),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEmailAuthSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.only(left: 24, right: 24, top: 32, bottom: 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isLogin ? 'Sign In with Email' : 'Sign Up with Email',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        text: _isLogin ? 'Sign In' : 'Sign Up',
                        isLoading: _isLoading,
                        onPressed: () => _handleEmailAuth(setSheetState),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setSheetState(() => _isLogin = !_isLogin),
                        child: Text(_isLogin ? "Don't have an account? Sign Up" : 'Already have an account? Sign In'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
                'Stride by Moops',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                'The offline-first running tracker.\nNo account required.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 48),
              
              PrimaryButton(
                text: 'Start Tracking Now (Offline)',
                isLoading: _isLoading,
                onPressed: _handleGuestLogin,
              ).animate().slideY(begin: 0.1, delay: 400.ms).fadeIn(delay: 400.ms),
              
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(child: Divider(color: Theme.of(context).colorScheme.surface)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Or, sign in to enable cloud backups',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Theme.of(context).colorScheme.surface)),
                ],
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 32),
              
              OutlinedButton.icon(
                onPressed: _handleGoogleLogin,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ).animate().slideY(begin: 0.1, delay: 600.ms).fadeIn(delay: 600.ms),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: _showEmailAuthSheet,
                child: const Text('Continue with Email'),
              ).animate().fadeIn(delay: 700.ms),
              
              const SizedBox(height: 48),
              
              Center(
                child: Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/images/moops-logo-dark.png'
                      : 'assets/images/moops-logo-light.png',
                  height: 48,
                  opacity: const AlwaysStoppedAnimation(0.3),
                ).animate().fadeIn(delay: 900.ms),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
