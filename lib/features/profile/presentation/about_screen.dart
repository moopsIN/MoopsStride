import 'package:flutter/material.dart';
import 'package:stride/theme/glass_container.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchUrl() async {
    final url = Uri.parse('https://moops.in');
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final isDarkMode = theme.brightness == Brightness.dark;
    final logoAsset = isDarkMode
        ? 'assets/images/moops-logo-dark.png'
        : 'assets/images/moops-logo-light.png';

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
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
              const SizedBox(height: 32),
              Center(
                child: Image.asset(
                  logoAsset,
                  height: 80,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.fitness_center_rounded, size: 80, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Moops Design',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              GlassContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Stride by Moops',
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Stride is a beautiful and minimalist running and activity tracker designed to help you hit your fitness goals without the clutter. Built with passion and focus on premium user experiences.',
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5, color: muted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    InkWell(
                      onTap: _launchUrl,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.language_rounded, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'moops.in',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  'Version 1.0.0',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
