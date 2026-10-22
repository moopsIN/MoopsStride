import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/theme/brutal_card.dart';
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

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
          const Spacer(),
          Text(
            value.isNotEmpty ? value : '—',
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
      height: 1,
      thickness: 1,
    );
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
                child: const Text('Logout Anyway', style: TextStyle(color: Colors.red)),
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
            child: const Text('Delete Account', style: TextStyle(color: Colors.red)),
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
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);
    final isGuest = user == null;
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final isKm = ref.watch(isKmProvider);
    final isKg = ref.watch(isKgProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Identity card
              BrutalCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isGuest ? 'Guest User' : (user.email ?? 'User'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isGuest
                                ? 'Tracking locally on this device'
                                : switch (ref.watch(pendingSyncCountProvider).value) {
                                    null || 0 => 'Synced to your account',
                                    1 => '1 change waiting to sync',
                                    final n => '$n changes waiting to sync',
                                  },
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: profileState.when(
                          data: (state) {
                            final gender = state.gender;
                            if (gender == 'Male') {
                              return Image.asset('assets/images/male_avatar.png', fit: BoxFit.cover);
                            } else if (gender == 'Female') {
                              return Image.asset('assets/images/female_avatar.png', fit: BoxFit.cover);
                            } else {
                              return Image.asset('assets/images/other_avatar.png', fit: BoxFit.cover);
                            }
                          },
                          loading: () => Icon(Icons.person_rounded, size: 28, color: theme.colorScheme.primary),
                          error: (err, stack) => Icon(Icons.person_rounded, size: 28, color: theme.colorScheme.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.08),

              const SizedBox(height: 32),

              _sectionLabel(context, 'PERSONAL DETAILS'),
              profileState.when(
                data: (state) {
                  return BrutalCard(
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    child: Column(
                      children: [
                        _buildDetailRow(context, Icons.flag_rounded, 'Goal', state.goal),
                        _divider(context),
                        _buildDetailRow(
                            context, Icons.trending_up_rounded, 'Experience', state.experienceLevel),
                        _divider(context),
                        _buildDetailRow(
                            context, Icons.bolt_rounded, 'Activity', state.activityLevel),
                        _divider(context),
                        _buildDetailRow(
                            context, Icons.person_outline_rounded, 'Gender', state.gender),
                        _divider(context),
                        _buildDetailRow(
                            context, Icons.cake_rounded, 'Age', '${state.age} yrs'),
                        _divider(context),
                        _buildDetailRow(
                            context, Icons.height_rounded, 'Height', '${state.height} cm (${formatHeightToFtIn(state.height)})'),
                        _divider(context),
                        _buildDetailRow(
                            context, Icons.monitor_weight_rounded, 'Weight', isKg ? '${state.weight} kg' : '${kgToLbs(state.weight).toStringAsFixed(1)} lbs'),
                        const SizedBox(height: 4),
                        _divider(context),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 4, right: 4),
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: Text(
                                'Edit Details', 
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold, 
                                  color: theme.colorScheme.primary
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Failed to load profile.', style: theme.textTheme.bodyMedium),
                ),
              ),

              const SizedBox(height: 28),

              _sectionLabel(context, 'PREFERENCES'),
              BrutalCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                    SwitchListTile.adaptive(
                      title: const Text('Distance Units'),
                      subtitle: Text(isKm ? 'Kilometers (km)' : 'Miles (mi)'),
                      value: isKm,
                      onChanged: (val) => ref.read(isKmProvider.notifier).setKm(val),
                      activeTrackColor: theme.colorScheme.primary,
                    ),
                    _divider(context),
                    SwitchListTile.adaptive(
                      title: const Text('Weight Units'),
                      subtitle: Text(isKg ? 'Kilograms (kg)' : 'Pounds (lbs)'),
                      value: isKg,
                      onChanged: (val) => ref.read(isKgProvider.notifier).setKg(val),
                      activeTrackColor: theme.colorScheme.primary,
                    ),
                    _divider(context),
                    SwitchListTile.adaptive(
                      title: const Text('Dark Mode'),
                      value: isDarkMode,
                      onChanged: (val) => ref.read(themeModeProvider.notifier).toggleTheme(val),
                      activeTrackColor: theme.colorScheme.primary,
                    ),
                  ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              _sectionLabel(context, 'ACCOUNT'),
              BrutalCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                    if (!isGuest) ...[
                      ListTile(
                        leading: Icon(Icons.cloud_sync_rounded, color: theme.colorScheme.onSurface),
                        title: const Text('Sync Now'),
                        trailing: _isSyncing
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : null,
                        onTap: _isSyncing ? null : _handleSyncNow,
                      ),
                      _divider(context),
                    ],
                    ListTile(
                      leading: Icon(Icons.info_outline_rounded, color: theme.colorScheme.onSurface),
                      title: const Text('About'),
                      trailing: Icon(Icons.chevron_right_rounded,
                          size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AboutScreen()),
                        );
                      },
                    ),
                    _divider(context),
                    ListTile(
                      leading: Icon(
                        isGuest ? Icons.login_rounded : Icons.logout_rounded,
                        color: isGuest ? theme.colorScheme.primary : const Color(0xFFE5484D),
                      ),
                      title: Text(
                        isGuest ? 'Sign In to Sync' : 'Sign Out',
                        style: TextStyle(
                          color: isGuest ? theme.colorScheme.primary : const Color(0xFFE5484D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () async {
                        if (isGuest) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AuthScreen()),
                          );
                        } else {
                          await _handleSignOut();
                        }
                      },
                    ),
                    if (!isGuest) ...[
                      _divider(context),
                      ListTile(
                        leading: const Icon(Icons.delete_forever_rounded, color: Color(0xFFE5484D)),
                        title: const Text(
                          'Delete Account',
                          style: TextStyle(color: Color(0xFFE5484D), fontWeight: FontWeight.w600),
                        ),
                        trailing: _isDeleting
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : null,
                        onTap: _isDeleting ? null : _handleDeleteAccount,
                      ),
                    ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
