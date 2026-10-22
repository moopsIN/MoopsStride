import 'package:flutter/material.dart';
import 'package:stride/core/widgets/moop.dart';
import 'package:stride/core/widgets/screen_header.dart';
import 'package:stride/theme/app_theme.dart';
import 'package:stride/theme/brutal_card.dart';
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
    final c = context.stride;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
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
                  const SizedBox(height: 14),
                  BrutalCard(
                    color: c.sky,
                    onTap: _launchUrl,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(
                      children: [
                        Icon(Icons.language_rounded, color: c.onPastel),
                        const SizedBox(width: 12),
                        Expanded(child: Text('moops.in', style: text.titleMedium?.copyWith(color: c.onPastel))),
                        Icon(Icons.arrow_outward_rounded, color: c.onPastel),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('VERSION 1.0.0', textAlign: TextAlign.center, style: text.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
