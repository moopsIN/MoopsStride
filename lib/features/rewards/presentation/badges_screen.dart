import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/core/widgets/screen_header.dart';
import 'package:stride/features/rewards/domain/badges.dart';
import 'package:stride/features/rewards/domain/rewards_engine.dart';
import 'package:stride/features/rewards/presentation/rewards_widgets.dart';
import 'package:stride/features/rewards/providers/rewards_provider.dart';
import 'package:stride/theme/app_theme.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardsProvider);
    final text = Theme.of(context).textTheme;
    final earned = [for (final id in BadgeId.values) if (rewards.earned.containsKey(id)) id];
    final progressById = {for (final p in rewards.locked) p.id: p};

    Widget grid(List<BadgeId> ids, {required bool isEarned}) => GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 0.82,
          children: [
            for (final id in ids)
              BadgeTile(
                id: id,
                earned: isEarned,
                progress: progressById[id]?.fraction,
                onTap: () => _showDetail(context, id, rewards),
              ),
          ],
        );

    final lockedIds = [for (final p in rewards.locked) p.id];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'badges'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 28),
                children: [
                  LevelCard(rewards: rewards),
                  const SizedBox(height: 22),
                  Text('EARNED · ${earned.length} OF ${BadgeId.values.length}', style: text.labelSmall),
                  const SizedBox(height: 8),
                  if (earned.isEmpty)
                    Text('Finish a run to earn your first badge.', style: text.bodyMedium)
                  else
                    grid(earned, isEarned: true),
                  if (lockedIds.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text('STILL TO EARN', style: text.labelSmall),
                    const SizedBox(height: 8),
                    grid(lockedIds, isEarned: false),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, BadgeId id, RewardsSnapshot rewards) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    final def = badgeDef(id);
    final earned = rewards.earned[id];
    final progress = rewards.locked.where((p) => p.id == id).firstOrNull;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 120, child: BadgeTile(id: id, earned: earned != null, progress: progress?.fraction)),
              const SizedBox(height: 16),
              Text(badgeHeadline(id), style: text.headlineLarge, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(def.description, style: text.bodyLarge?.copyWith(color: c.inkMuted), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                earned != null
                    ? 'EARNED ${earned.earnedAt.day} ${months[earned.earnedAt.month - 1].toUpperCase()} ${earned.earnedAt.year}'
                    : (progress?.hint ?? '').toUpperCase(),
                style: text.labelMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
