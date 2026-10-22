import 'package:flutter/material.dart';
import 'package:stride/core/widgets/moop.dart';

/// Nothing-here-yet message, delivered by a (usually sleepy) Moop.
class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final MoopMood mood;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.mood = MoopMood.sleepy,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Moop(size: 120, mood: mood),
            const SizedBox(height: 20),
            Text(title, style: text.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: text.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
