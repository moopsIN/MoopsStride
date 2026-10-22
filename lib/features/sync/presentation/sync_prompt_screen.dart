import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/core/widgets/primary_button.dart';
import 'package:stride/features/sync/providers/sync_engine.dart';
import 'package:stride/features/auth/providers/auth_provider.dart';
import 'package:stride/features/tracking/presentation/tracking_screen.dart';
import 'package:stride/features/onboarding/presentation/onboarding_screen.dart';
import 'package:stride/core/database/local_db.dart';

class SyncPromptScreen extends ConsumerStatefulWidget {
  /// True when we couldn't tell whether the account has cloud data. The user
  /// is offered a retry instead of being sent to onboarding as if new.
  final bool cloudUnreachable;

  const SyncPromptScreen({super.key, this.cloudUnreachable = false});

  /// Where a signed-in user with no local profile should go next.
  static Future<Widget> routeFor(WidgetRef ref, String uid) async {
    switch (await ref.read(syncEngineProvider).checkCloudData(uid)) {
      case CloudDataStatus.exists:
        return const SyncPromptScreen();
      case CloudDataStatus.unknown:
        return const SyncPromptScreen(cloudUnreachable: true);
      case CloudDataStatus.empty:
        return const OnboardingScreen();
    }
  }

  @override
  ConsumerState<SyncPromptScreen> createState() => _SyncPromptScreenState();
}

class _SyncPromptScreenState extends ConsumerState<SyncPromptScreen> {
  bool _isSyncing = false;
  bool _isWiping = false;

  Future<void> _handleSyncNow() async {
    final user = ref.read(authProvider);
    if (user == null) return;
    setState(() => _isSyncing = true);

    final Widget next;
    try {
      if (widget.cloudUnreachable) {
        // Retry the check; it decides between this prompt and onboarding.
        next = await SyncPromptScreen.routeFor(ref, user.uid);
        if (next is SyncPromptScreen && next.cloudUnreachable) {
          throw SyncException("Still can't reach the cloud. Check your connection.");
        }
      } else {
        await ref.read(syncEngineProvider).pullFromCloud(user.uid);
        // Runs but no saved profile (older accounts): ask for real details
        // rather than inventing them, since calories depend on weight.
        next = await LocalDatabase.instance.getUserProfile() != null
            ? const TrackingScreen()
            : const OnboardingScreen();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is SyncException ? e.message : 'Sync failed: $e'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  /// Offline fallback: set up locally now; cloud history merges in on the
  /// next successful sync instead of being lost.
  void _handleContinueOffline() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  Future<void> _handleStartFresh() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Fresh?'),
        content: const Text('This will permanently delete all your previous runs and profile data from the cloud. This action cannot be undone.\n\nAre you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Everything', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isWiping = true);
    final user = ref.read(authProvider);
    if (user != null) {
      await ref.read(syncEngineProvider).wipeCloudData(user.uid);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.cloud_sync_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack).fadeIn(),
              
              const SizedBox(height: 32),
              
              Text(
                widget.cloudUnreachable ? "Couldn't Reach the Cloud" : 'Previous Data Found',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 16),
              
              Text(
                widget.cloudUnreachable
                    ? "We couldn't check your account for saved runs. Try again once you're online, or continue and they'll be merged in automatically later."
                    : 'We found your profile and past runs saved to your account.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
              
              const Spacer(),
              
              PrimaryButton(
                text: widget.cloudUnreachable ? 'Try Again' : 'Sync Now',
                isLoading: _isSyncing,
                onPressed: (_isSyncing || _isWiping) ? () {} : () { _handleSyncNow(); },
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
              
              const SizedBox(height: 16),
              
              if (widget.cloudUnreachable)
                TextButton(
                  onPressed: _isSyncing ? null : _handleContinueOffline,
                  child: const Text('Continue Without Syncing'),
                ).animate().fadeIn(delay: 500.ms)
              else
              ElevatedButton(
                onPressed: (_isSyncing || _isWiping) ? null : () { _handleStartFresh(); },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  elevation: 0,
                ),
                child: _isWiping 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                  : const Text('Start Fresh (Delete Cloud Data)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
              
              const SizedBox(height: 48),
              
              // Bottom Logo & Text
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      Theme.of(context).brightness == Brightness.dark
                          ? 'assets/images/moops-logo-dark.png'
                          : 'assets/images/moops-logo-light.png',
                      height: 48,
                      opacity: const AlwaysStoppedAnimation(0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'STRIDE BY MOOPS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 600.ms),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
