import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:stride/features/rewards/providers/rewards_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/theme/app_theme.dart';
import 'package:stride/theme/brutal_card.dart';
import 'package:stride/core/widgets/moop.dart';
import 'package:stride/core/widgets/screen_header.dart';
import 'package:stride/theme/theme_provider.dart';
import 'package:stride/features/auth/providers/auth_provider.dart';
import 'package:stride/features/auth/presentation/auth_screen.dart';
import 'package:stride/features/profile/presentation/edit_profile_screen.dart';
import 'package:stride/features/profile/presentation/about_screen.dart';
import 'package:stride/features/profile/providers/profile_provider.dart';
import 'package:stride/core/providers/preferences_provider.dart';
import 'package:stride/core/utils/formatters.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/features/sync/providers/sync_engine.dart';
import 'package:stride/features/progress/providers/progress_provider.dart';
import 'package:stride/features/onboarding/providers/onboarding_provider.dart';
import 'package:stride/features/tracking/providers/tracking_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isSyncing = false;
  bool _isDeleting = false;

  Future<void> _handleSyncNow() async {
    setState(() => _isSyncing = true);
    final ok = await ref.read(syncEngineProvider).fullSync(force: true);
    if (!mounted) return;
    setState(() => _isSyncing = false);
    ref.invalidate(pendingSyncCountProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Everything is synced.'
          : "Couldn't sync everything. Check your connection and try again."),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// A run in progress holds a foreground location service and in-memory
  /// state that would leak into the next account.
  bool _blockIfRunInProgress() {
    final status = ref.read(trackingProvider).status;
    if (status != TrackingStatus.active && status != TrackingStatus.paused) return false;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Finish your current run first.'),
      behavior: SnackBarBehavior.floating,
    ));
    return true;
  }

  Future<void> _handleSignOut() async {
    if (_blockIfRunInProgress()) return;

    final success = await ref.read(syncEngineProvider).syncUnsyncedActivities();
    if (!success && mounted) {
      ref.invalidate(pendingSyncCountProvider);
      final pending = await ref.read(pendingSyncCountProvider.future);
      if (!mounted) return;
      if (pending > 0) {
        final shouldForce = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Unsynced Data'),
            content: const Text('Some runs or profile changes haven\'t been synced to the cloud yet. Logging out will wipe them from this device.\n\nAre you sure you want to logout?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop(false);
                  _handleSignOut(); // try again
                },
                child: const Text('Try Again'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Logout Anyway', style: TextStyle(color: Theme.of(ctx).colorScheme.error, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );

        if (shouldForce != true) return;
      }
    }

    await ref.read(authProvider.notifier).signOut();
    await _clearLocalSessionAndExit();
  }

  Future<void> _handleDeleteAccount() async {
    if (_blockIfRunInProgress()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
            'This permanently deletes your account, all your runs and your profile, from the cloud and from this device. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete Account', style: TextStyle(color: Theme.of(ctx).colorScheme.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final auth = ref.read(authProvider.notifier);
    final user = ref.read(authProvider);
    if (user == null) return;

    String? password;
    if (!auth.usesGoogle) {
      password = await _askPassword();
      if (password == null) return;
    }

    setState(() => _isDeleting = true);
    try {
      if (!await auth.reauthenticate(password: password)) return;
      await ref.read(syncEngineProvider).wipeCloudData(user.uid);
      await auth.deleteAccount();
    } catch (e) {
      if (mounted) {
        final message = switch (e) {
          SyncException(:final message) => message,
          FirebaseAuthException(code: 'invalid-credential' || 'wrong-password') =>
            'Incorrect password.',
          FirebaseAuthException(code: 'network-request-failed') =>
            'No connection. Check your network and try again.',
          _ => "Couldn't delete your account: $e",
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }

    await _clearLocalSessionAndExit();
  }

  Future<String?> _askPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Your Password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  /// Removes everything the previous user left on this device, in storage and
  /// in memory, then restarts at the auth screen with a fresh navigation stack.
  Future<void> _clearLocalSessionAndExit() async {
    await LocalDatabase.instance.clearDatabase();
    // Celebrated-badge memory belongs to the account that just left.
    await ref.read(rewardsSeenStoreProvider).clear();
    try {
      final shared = File('${(await getTemporaryDirectory()).path}/stride_run_summary.png');
      if (await shared.exists()) await shared.delete();
    } catch (_) {}

    ref.invalidate(progressProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(onboardingProvider);
    ref.invalidate(pendingSyncCountProvider);
    ref.read(trackingProvider.notifier).reset();

    if (mounted) {
      // The settings route sits on top of the home screen; replacing only it
      // left a signed-out home screen one back-press away.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);
    final isGuest = user == null;
    final isDarkMode = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
    final isKm = ref.watch(isKmProvider);
    final isKg = ref.watch(isKgProvider);

    final status = isGuest
        ? 'Tracking locally on this device'
        : switch (ref.watch(pendingSyncCountProvider).value) {
            null || 0 => 'Synced to your account',
            1 => '1 change waiting to sync',
            final n => '$n changes waiting to sync',
          };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'settings'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 28),
                children: [
                  // Identity
                  BrutalCard(
                    color: c.sage,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: Brutal.box(c, color: c.surface, radius: 32, shadow: 0),
                          child: const Center(child: Moop(size: 44)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isGuest ? 'guest runner' : (user.email ?? 'runner'),
                                style: text.headlineSmall?.copyWith(color: c.onPastel),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(status, style: text.bodyMedium?.copyWith(color: c.onPastel)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  _Section(
                    label: 'ABOUT YOU',
                    trailing: _SmallButton(
                      label: 'EDIT',
                      icon: Icons.edit_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      ),
                    ),
                  ),
                  profileState.when(
                    data: (p) => BrutalCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Column(
                        children: [
                          _DetailRow(icon: Icons.flag_rounded, label: 'Goal', value: p.goal),
                          _DetailRow(icon: Icons.trending_up_rounded, label: 'Experience', value: p.experienceLevel),
                          _DetailRow(icon: Icons.bolt_rounded, label: 'Activity', value: p.activityLevel),
                          _DetailRow(icon: Icons.person_outline_rounded, label: 'Gender', value: p.gender),
                          _DetailRow(icon: Icons.cake_rounded, label: 'Age', value: '${p.age} yrs'),
                          _DetailRow(
                            icon: Icons.height_rounded,
                            label: 'Height',
                            value: '${p.height.toStringAsFixed(0)} cm (${formatHeightToFtIn(p.height)})',
                          ),
                          _DetailRow(
                            icon: Icons.monitor_weight_rounded,
                            label: 'Weight',
                            value: isKg
                                ? '${p.weight.toStringAsFixed(1)} kg'
                                : '${kgToLbs(p.weight).toStringAsFixed(1)} lbs',
                            last: true,
                          ),
                        ],
                      ),
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, stack) => Text("Couldn't load your profile.", style: text.bodyMedium),
                  ),

                  const _Section(label: 'PREFERENCES'),
                  BrutalCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    // Switch tiles paint ripples on the nearest Material, which
                    // the card's colour would otherwise hide.
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                      children: [
                        _SwitchRow(
                          title: 'Distance in kilometres',
                          subtitle: isKm ? 'Kilometres (km)' : 'Miles (mi)',
                          value: isKm,
                          onChanged: (v) => ref.read(isKmProvider.notifier).setKm(v),
                        ),
                        _SwitchRow(
                          title: 'Weight in kilograms',
                          subtitle: isKg ? 'Kilograms (kg)' : 'Pounds (lbs)',
                          value: isKg,
                          onChanged: (v) => ref.read(isKgProvider.notifier).setKg(v),
                        ),
                        _SwitchRow(
                          title: 'Dark mode',
                          value: isDarkMode,
                          onChanged: (v) => ref.read(themeModeProvider.notifier).toggleTheme(v),
                        ),
                      ],
                      ),
                    ),
                  ),

                  const _Section(label: 'ACCOUNT'),
                  if (!isGuest)
                    _ActionRow(
                      icon: Icons.cloud_sync_rounded,
                      label: 'Sync now',
                      color: c.sky,
                      busy: _isSyncing,
                      onTap: _isSyncing ? null : _handleSyncNow,
                    ),
                  _ActionRow(
                    icon: Icons.info_outline_rounded,
                    label: 'About Stride',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                  ),
                  _ActionRow(
                    icon: isGuest ? Icons.login_rounded : Icons.logout_rounded,
                    label: isGuest ? 'Sign in to back up runs' : 'Sign out',
                    color: isGuest ? c.butter : null,
                    onTap: () async {
                      if (isGuest) {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
                      } else {
                        await _handleSignOut();
                      }
                    },
                  ),
                  if (!isGuest)
                    _ActionRow(
                      icon: Icons.delete_forever_rounded,
                      label: 'Delete account',
                      color: c.blush,
                      busy: _isDeleting,
                      onTap: _isDeleting ? null : _handleDeleteAccount,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const _Section({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.labelSmall)),
          ?trailing,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool last;

  const _DetailRow({required this.icon, required this.label, required this.value, this.last = false});

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.outline.withValues(alpha: 0.12), width: 1.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.ink),
          const SizedBox(width: 12),
          Text(label, style: text.bodyMedium),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              textAlign: TextAlign.right,
              style: text.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({required this.title, required this.value, required this.onChanged, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      value: value,
      onChanged: onChanged,
      activeTrackColor: context.stride.brand,
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool busy;
  final VoidCallback? onTap;

  const _ActionRow({required this.icon, required this.label, this.color, this.busy = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final fg = color == null ? c.ink : c.onPastel;
    return BrutalCard(
      margin: const EdgeInsets.only(bottom: 6),
      color: color,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 22, color: fg),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: fg))),
          busy
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
              : Icon(Icons.arrow_forward_rounded, size: 20, color: fg),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SmallButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    return BrutalCard(
      shadow: 3,
      borderRadius: Brutal.radiusPill,
      color: c.butter,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c.onPastel),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.onPastel)),
        ],
      ),
    );
  }
}
