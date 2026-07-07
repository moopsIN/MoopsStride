import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/theme/glass_container.dart';
import 'package:stride/theme/theme_provider.dart';
import 'package:stride/features/auth/providers/auth_provider.dart';
import 'package:stride/features/auth/presentation/auth_screen.dart';
import 'package:stride/features/profile/presentation/edit_profile_screen.dart';
import 'package:stride/features/profile/presentation/about_screen.dart';
import 'package:stride/features/profile/providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isKm = true;

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
    return Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);
    final isGuest = user == null;
    final isDarkMode = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

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
              GlassContainer(
                borderRadius: 24,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(Icons.person_rounded, size: 42, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isGuest ? 'Guest User' : (user.email ?? 'User'),
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGuest ? 'Tracking locally on this device' : 'Synced to your account',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.08),

              const SizedBox(height: 32),

              _sectionLabel(context, 'PERSONAL DETAILS'),
              profileState.when(
                data: (state) {
                  return GlassContainer(
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
                            context, Icons.height_rounded, 'Height', '${state.height} cm'),
                        _divider(context),
                        _buildDetailRow(
                            context, Icons.monitor_weight_rounded, 'Weight', '${state.weight} kg'),
                        const SizedBox(height: 4),
                        _divider(context),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                              );
                            },
                            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Edit Details'),
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
              GlassContainer(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      title: const Text('Distance Units'),
                      subtitle: Text(_isKm ? 'Kilometers (km)' : 'Miles (mi)'),
                      value: _isKm,
                      onChanged: (val) => setState(() => _isKm = val),
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

              const SizedBox(height: 28),

              _sectionLabel(context, 'ACCOUNT'),
              GlassContainer(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
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
                          await ref.read(authProvider.notifier).signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const AuthScreen()),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
