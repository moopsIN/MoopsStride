import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/core/widgets/primary_button.dart';
import 'package:stride/features/onboarding/presentation/onboarding_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleGuestLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  void _handleEmailLogin() {
    setState(() => _isLoading = true);
    // Mock login delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isLoading = false);
        // Will connect to Firebase in Phase 6
        _handleGuestLogin();
      }
    });
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
                'Welcome to Stride',
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
                text: 'Sign In',
                isLoading: _isLoading,
                onPressed: _handleEmailLogin,
              ).animate().slideY(begin: 0.2, delay: 600.ms).fadeIn(delay: 600.ms),
              
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
                onPressed: _handleEmailLogin,
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
            ],
          ),
        ),
      ),
    );
  }
}
