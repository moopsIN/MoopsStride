import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/theme/glass_container.dart';
import 'package:stride/theme/theme_provider.dart';
import 'package:stride/features/auth/providers/auth_provider.dart';
import 'package:stride/features/auth/presentation/auth_screen.dart';
import 'package:stride/features/profile/presentation/edit_profile_screen.dart';
import 'package:stride/features/profile/providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isKm = true;

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value.isNotEmpty ? value : '-', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);
    final isGuest = user == null;
    final isDarkMode = themeMode == ThemeMode.dark || (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              isGuest ? 'Guest User' : user.email ?? 'User',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            Text(
              'PERSONAL DETAILS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
            ),
            const SizedBox(height: 16),
            
            profileState.when(
              data: (state) {
                return GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDetailRow('Goal', state.goal),
                      const Divider(height: 16, color: Colors.white24),
                      _buildDetailRow('Experience', state.experienceLevel),
                      const Divider(height: 16, color: Colors.white24),
                      _buildDetailRow('Activity', state.activityLevel),
                      const Divider(height: 16, color: Colors.white24),
                      _buildDetailRow('Height', '${state.height} cm'),
                      const Divider(height: 16, color: Colors.white24),
                      _buildDetailRow('Weight', '${state.weight} kg'),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                            );
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit Details'),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => const Text('Failed to load profile.'),
            ),
            
            const SizedBox(height: 32),
            
            Text(
              'PREFERENCES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
            ),
            const SizedBox(height: 16),
            
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: const Text('Distance Units'),
                    subtitle: Text(_isKm ? 'Kilometers (km)' : 'Miles (mi)'),
                    value: _isKm,
                    onChanged: (val) => setState(() => _isKm = val),
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                  ),
                  const Divider(height: 1, color: Colors.white24),
                  SwitchListTile.adaptive(
                    title: const Text('Dark Mode'),
                    value: isDarkMode,
                    onChanged: (val) => ref.read(themeModeProvider.notifier).toggleTheme(val),
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            Text(
              'ACCOUNT',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
            ),
            const SizedBox(height: 16),
            
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      isGuest ? Icons.login : Icons.logout,
                      color: isGuest ? Theme.of(context).colorScheme.primary : Colors.redAccent,
                    ),
                    title: Text(
                      isGuest ? 'Sign In to Sync' : 'Sign Out',
                      style: TextStyle(
                        color: isGuest ? Theme.of(context).colorScheme.primary : Colors.redAccent,
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
    );
  }
}
