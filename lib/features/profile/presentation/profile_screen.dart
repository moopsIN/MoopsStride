import 'package:flutter/material.dart';
import 'package:stride/theme/glass_container.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isKm = true;
  bool _isDarkMode = true;

  @override
  Widget build(BuildContext context) {
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
              'Guest User',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            
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
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  const Divider(height: 1, color: Colors.white24),
                  SwitchListTile.adaptive(
                    title: const Text('Dark Mode'),
                    value: _isDarkMode,
                    onChanged: (val) => setState(() => _isDarkMode = val),
                    activeColor: Theme.of(context).colorScheme.primary,
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
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  // Phase 6 logic
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
