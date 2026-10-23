import 'package:flutter/material.dart';
import 'package:stride/theme/notebook_background.dart';
import 'package:stride/core/widgets/moop.dart';
import 'package:stride/core/widgets/screen_header.dart';
import 'package:stride/theme/app_theme.dart';
import 'package:stride/theme/brutal_card.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// Always hands the link to the OS's own browser app (not an in-app
  /// WebView or Custom Tab), on both Android and iOS.
  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;

    Widget linkCard({required IconData icon, required String label, required Color color, required String url}) {
      return BrutalCard(
        color: color,
        onTap: () => _open(url),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: c.onPastel),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: text.titleMedium?.copyWith(color: c.onPastel))),
            Icon(Icons.arrow_outward_rounded, color: c.onPastel),
          ],
        ),
      );
    }

    return Scaffold(
      body: NotebookBackground(
        seed: 10,
        child: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'about'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 16, 28),
                  children: [
                    BrutalCard(
                      color: c.butter,
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                      child: Column(
                        children: [
                          const Moop(size: 120, mood: MoopMood.happy),
                          const SizedBox(height: 14),
                          Text('stride', style: text.displayLarge?.copyWith(color: c.onPastel, letterSpacing: -1.5)),
                          const SizedBox(height: 6),
                          BrutalPill(text: 'BY MOOPS', color: c.blush),
                          const SizedBox(height: 16),
                          Text(
                            'A cute, offline-first running tracker. Your runs live on your phone; sign in only if you want them backed up.',
                            style: text.bodyLarge?.copyWith(color: c.onPastel, height: 1.45),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    BrutalCard(
                      color: c.sage,
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const Moop(size: 44, animate: false),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('meet Moop', style: text.headlineSmall?.copyWith(color: c.onPastel)),
                                const SizedBox(height: 2),
                                Text(
                                  "The Moops mascot. Soft on the outside, serious underneath. It runs when you run.",
                                  style: text.bodyMedium?.copyWith(color: c.onPastel),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text('LINKS', style: text.labelSmall),
                    const SizedBox(height: 8),
                    linkCard(
                      icon: Icons.language_rounded,
                      label: 'Stride project page',
                      color: c.sky,
                      url: 'https://moops.in/work/stride',
                    ),
                    const SizedBox(height: 8),
                    linkCard(
                      icon: Icons.code_rounded,
                      label: 'Source on GitHub',
                      color: c.surface,
                      url: 'https://github.com/moopsIN/MoopsStride',
                    ),
                    const SizedBox(height: 8),
                    linkCard(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy policy',
                      color: c.butter,
                      url: 'https://moops.in/work/stride/privacy-policy',
                    ),
                    const SizedBox(height: 8),
                    linkCard(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete your account',
                      color: c.blush,
                      url: 'https://moops.in/work/stride/delete-account',
                    ),
                    const SizedBox(height: 28),
                    Text('VERSION 1.0.0', textAlign: TextAlign.center, style: text.labelSmall),
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
