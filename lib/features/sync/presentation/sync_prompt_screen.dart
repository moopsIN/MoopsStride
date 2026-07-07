import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/core/widgets/primary_button.dart';
import 'package:stride/features/sync/providers/sync_engine.dart';
import 'package:stride/features/auth/providers/auth_provider.dart';
import 'package:stride/features/tracking/presentation/tracking_screen.dart';
import 'package:stride/features/onboarding/presentation/onboarding_screen.dart';

class SyncPromptScreen extends ConsumerStatefulWidget {
  const SyncPromptScreen({super.key});

  @override
  ConsumerState<SyncPromptScreen> createState() => _SyncPromptScreenState();
}

class _SyncPromptScreenState extends ConsumerState<SyncPromptScreen> {
  bool _isSyncing = false;
  bool _isWiping = false;

  Future<void> _handleSyncNow() async {
    setState(() => _isSyncing = true);
    final user = ref.read(authProvider);
    if (user != null) {
      await ref.read(syncEngineProvider).downSync(user.uid);
    }
    
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TrackingScreen()),
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
                'Previous Data Found',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 16),
              
              Text(
                'We found profile data and past runs associated with your account in the cloud.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
              
              const Spacer(),
              
              PrimaryButton(
                text: 'Sync Now',
                isLoading: _isSyncing,
                onPressed: (_isSyncing || _isWiping) ? () {} : () { _handleSyncNow(); },
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
              
              const SizedBox(height: 16),
              
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
