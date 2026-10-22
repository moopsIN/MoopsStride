import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/core/widgets/primary_button.dart';
import 'package:stride/features/sync/providers/sync_engine.dart';
import 'package:stride/features/auth/providers/auth_provider.dart';
import 'package:stride/features/tracking/presentation/tracking_screen.dart';
import 'package:stride/features/onboarding/presentation/onboarding_screen.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/core/widgets/moop.dart';
import 'package:stride/theme/app_theme.dart';
import 'package:stride/theme/brutal_card.dart';

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
      try {
        await ref.read(syncEngineProvider).wipeCloudData(user.uid);
      } on SyncException catch (e) {
        if (!mounted) return;
        setState(() => _isWiping = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    final unreachable = widget.cloudUnreachable;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              BrutalCard(
                color: unreachable ? c.blush : c.sky,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                child: Column(
                  children: [
                    Moop(size: 120, mood: unreachable ? MoopMood.shocked : MoopMood.excited),
                    const SizedBox(height: 16),
                    Text(
                      unreachable ? "couldn't reach the cloud" : 'welcome back!',
                      style: text.headlineLarge?.copyWith(color: c.onPastel),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      unreachable
                          ? "We couldn't check your account for saved runs. Try again once you're online, or continue and they'll merge in automatically later."
                          : 'Your profile and past runs are saved to your account. Bring them to this device?',
                      style: text.bodyLarge?.copyWith(color: c.onPastel),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, curve: Curves.easeOut),
              const Spacer(),
              PrimaryButton(
                text: unreachable ? 'Try again' : 'Sync my runs',
                icon: unreachable ? Icons.refresh_rounded : Icons.cloud_download_rounded,
                isLoading: _isSyncing,
                onPressed: (_isSyncing || _isWiping) ? () {} : _handleSyncNow,
              ),
              const SizedBox(height: 10),
              if (unreachable)
                PrimaryButton(
                  text: 'Continue without syncing',
                  color: c.surface,
                  foregroundColor: c.ink,
                  onPressed: _isSyncing ? () {} : _handleContinueOffline,
                )
              else
                PrimaryButton(
                  text: 'Start fresh (delete cloud data)',
                  icon: Icons.delete_outline_rounded,
                  color: c.surface,
                  foregroundColor: c.coral,
                  isLoading: _isWiping,
                  onPressed: (_isSyncing || _isWiping) ? () {} : _handleStartFresh,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
