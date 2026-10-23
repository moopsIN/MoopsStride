import 'package:flutter/material.dart';
import 'package:stride/theme/notebook_background.dart';
import 'package:stride/theme/brutal_card.dart';
import 'package:stride/theme/app_theme.dart';
import 'package:stride/core/widgets/moop.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/core/widgets/primary_button.dart';
import 'package:stride/features/onboarding/presentation/onboarding_screen.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/tracking/presentation/tracking_screen.dart';
import 'package:stride/features/sync/presentation/sync_prompt_screen.dart';

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

  String _getErrorMessage(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'invalid-email' => 'That email address looks invalid.',
        'weak-password' => 'Choose a stronger password (at least 6 characters).',
        'email-already-in-use' => 'This email is already registered. Check your password, or reset it.',
        'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
        'network-request-failed' => 'No connection. Check your network and try again.',
        'user-disabled' => 'This account has been disabled.',
        'account-exists-with-different-credential' =>
          'This email is already registered with a password. Sign in with email instead.',
        _ => e.message ?? 'Authentication failed.',
      };
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
      final next = user == null
          ? const OnboardingScreen()
          : await SyncPromptScreen.routeFor(ref, user.uid);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );
    }
  }

  Future<void> _handleEmailAuth(StateSetter setSheetState) async {
    final email = _emailController.text.trim();
    // Not trimmed: spaces are legitimate password characters.
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    setSheetState(() => _isLoading = true);
    
    try {
      await ref.read(authProvider.notifier).signInWithEmail(email, password);
      
      if (mounted) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop(); // Close sheet
        await _routeAfterLogin();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' || e.code == 'user-not-found' || e.code == 'wrong-password') {
        if (mounted) {
          setSheetState(() => _isLoading = false);
          _showSignInFailedDialog(email, password, setSheetState);
        }
        return;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_getErrorMessage(e)),
          behavior: SnackBarBehavior.floating,
        ));
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

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Firebase reports a wrong password and an unknown email the same way
  /// (enumeration protection), so offer both paths instead of guessing.
  void _showSignInFailedDialog(String email, String password, StateSetter setSheetState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Couldn't Sign In"),
        content: Text(
            "The email or password is incorrect.\n\nNew to Stride? Create an account for $email."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _sendPasswordReset(email);
            },
            child: const Text('Forgot Password?'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Try Again'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showCreateAccountDialog(email, password, setSheetState);
            },
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }

  /// Asks for the password again so a typo can't silently become the
  /// account's password.
  void _showCreateAccountDialog(String email, String password, StateSetter setSheetState) {
    final confirmController = TextEditingController();
    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confirm the password for $email.'),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(labelText: 'Confirm password', errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (confirmController.text != password) {
                  setDialogState(() => error = "Passwords don't match");
                  return;
                }
                Navigator.of(ctx).pop();
                _createAccount(email, password, setSheetState);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    ).whenComplete(confirmController.dispose);
  }

  Future<void> _createAccount(String email, String password, StateSetter setSheetState) async {
    setSheetState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).signUpWithEmail(email, password);
      if (mounted) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop(); // close sheet
        _showSnack('Account created. Check your inbox to verify your email.');
        await _routeAfterLogin();
      }
    } catch (err) {
      if (mounted) _showSnack(_getErrorMessage(err));
    } finally {
      if (mounted) setSheetState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordReset(String email) async {
    if (email.isEmpty) {
      _showSnack('Enter your email first, then tap Forgot Password.');
      return;
    }
    try {
      await ref.read(authProvider.notifier).sendPasswordReset(email);
      // Same message whether or not the account exists, to avoid leaking it.
      if (mounted) _showSnack('If an account exists for $email, a reset link is on its way.');
    } catch (e) {
      if (mounted) _showSnack(_getErrorMessage(e));
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final signedIn = await ref.read(authProvider.notifier).signInWithGoogle();
      if (signedIn && mounted) {
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
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final text = Theme.of(context).textTheme;
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: context.stride.outline,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('continue with email', style: text.headlineLarge),
                      const SizedBox(height: 4),
                      Text("We'll sign you in, or help you create an account.", style: text.bodyMedium),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _sendPasswordReset(_emailController.text.trim()),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      PrimaryButton(
                        text: 'Continue',
                        isLoading: _isLoading,
                        onPressed: () => _handleEmailAuth(setSheetState),
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
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: NotebookBackground(
        seed: 1,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero block: Moop on butter, wordmark, promise.
                    BrutalCard(
                      color: c.butter,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('stride',
                                        style: text.displayLarge?.copyWith(fontSize: 60, color: c.onPastel, letterSpacing: -2)),
                                    const SizedBox(height: 6),
                                    BrutalPill(text: 'BY MOOPS', color: c.blush),
                                  ],
                                ),
                              ),
                              const Moop(size: 104, mood: MoopMood.happy, greet: true, idleWave: Duration(seconds: 9)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'The offline-first running tracker.\nNo account needed to start.',
                            style: text.bodyLarge?.copyWith(color: c.onPastel, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, curve: Curves.easeOut),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      text: 'Start tracking now',
                      icon: Icons.directions_run_rounded,
                      isLoading: _isLoading,
                      onPressed: _handleGuestLogin,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(child: Divider(color: c.outline.withValues(alpha: 0.25), thickness: 2)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OR BACK UP YOUR RUNS', style: text.labelSmall),
                        ),
                        Expanded(child: Divider(color: c.outline.withValues(alpha: 0.25), thickness: 2)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      text: 'Continue with Google',
                      icon: Icons.g_mobiledata_rounded,
                      color: c.surface,
                      foregroundColor: c.ink,
                      onPressed: _isLoading ? () {} : _handleGoogleLogin,
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      text: 'Continue with email',
                      icon: Icons.alternate_email_rounded,
                      color: c.sky,
                      onPressed: _isLoading ? () {} : _showEmailAuthSheet,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Your runs stay on this device unless you sign in.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
