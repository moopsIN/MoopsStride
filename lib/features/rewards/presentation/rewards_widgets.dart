import 'package:flutter/material.dart';
import 'package:stride/core/widgets/moop.dart';
import 'package:stride/features/rewards/domain/badges.dart';
import 'package:stride/features/rewards/domain/rewards_engine.dart';
import 'package:stride/theme/app_theme.dart';
import 'package:stride/theme/brutal_card.dart';

/// Icon and pastel for each badge family.
({IconData icon, Color color}) badgeLook(BadgeId id, StrideColors c) {
  final def = badgeDef(id);
  return switch (def.kind) {
    BadgeKind.firstRun => (icon: Icons.flag_rounded, color: c.sage),
    BadgeKind.singleRun => (icon: Icons.directions_run_rounded, color: c.butter),
    BadgeKind.lifetime => (icon: Icons.public_rounded, color: c.sky),
    BadgeKind.streak => (icon: Icons.local_fire_department_rounded, color: c.blush),
    BadgeKind.timeOfDay =>
      (icon: id == BadgeId.earlyBird ? Icons.wb_twilight_rounded : Icons.nightlight_round, color: c.sky),
    BadgeKind.weekend => (icon: Icons.weekend_rounded, color: c.sage),
  };
}

/// Badge title as a headline. Headlines are lowercase in this brand, but
/// numeric titles keep their case ("5K", not "5k").
String badgeHeadline(BadgeId id) {
  final title = badgeDef(id).title;
  return title.contains(RegExp(r'[0-9]')) ? title : title.toLowerCase();
}

/// An outlined progress bar in the brutal style.
class BrutalProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;

  const BrutalProgressBar({super.key, required this.value, this.color, this.height = 14});

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: c.outline, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(color: color ?? c.go),
          ),
        ),
      ),
    );
  }
}

/// Level, XP progress and Moop at its current growth stage.
class LevelCard extends StatelessWidget {
  final RewardsSnapshot rewards;
  final VoidCallback? onTap;

  const LevelCard({super.key, required this.rewards, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    final r = rewards;
    final fraction = r.isMaxLevel || r.xpForLevel == 0 ? 1.0 : r.xpIntoLevel / r.xpForLevel;
    return BrutalCard(
      color: c.butter,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 16),
      child: Row(
        children: [
          Moop(size: 64, growth: r.moopGrowth, mood: MoopMood.happy),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('level ${r.level}', style: text.headlineMedium?.copyWith(color: c.onPastel))),
                    if (onTap != null) Icon(Icons.arrow_forward_rounded, color: c.onPastel),
                  ],
                ),
                const SizedBox(height: 8),
                BrutalProgressBar(value: fraction),
                const SizedBox(height: 6),
                Text(
                  r.isMaxLevel
                      ? '${r.xp} XP · MAX LEVEL'
                      : '${r.xpIntoLevel} / ${r.xpForLevel} XP TO LEVEL ${r.level + 1}',
                  style: text.labelSmall?.copyWith(color: c.onPastel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A badge in the grid: coloured when earned, outlined with progress when not.
class BadgeTile extends StatelessWidget {
  final BadgeId id;
  final bool earned;
  final double? progress;
  final VoidCallback? onTap;

  const BadgeTile({super.key, required this.id, required this.earned, this.progress, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    final look = badgeLook(id, c);
    final fg = earned ? c.onPastel : c.inkMuted;
    return BrutalCard(
      color: earned ? look.color : c.surfaceAlt,
      shadow: earned ? Brutal.shadow : 2,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: earned ? c.surface : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: earned ? c.outline : fg.withValues(alpha: 0.5), width: 2),
            ),
            child: Icon(earned ? look.icon : Icons.lock_rounded, size: 22, color: earned ? c.ink : fg),
          ),
          const SizedBox(height: 8),
          Text(
            badgeDef(id).title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.labelMedium?.copyWith(color: fg, height: 1.2),
          ),
          if (!earned && progress != null) ...[
            const SizedBox(height: 6),
            BrutalProgressBar(value: progress!, height: 8, color: look.color),
          ],
        ],
      ),
    );
  }
}
