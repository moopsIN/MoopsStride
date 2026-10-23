import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stride/core/widgets/moop.dart';
import 'package:stride/core/widgets/primary_button.dart';
import 'package:stride/features/rewards/domain/badges.dart';
import 'package:stride/features/rewards/domain/rewards_engine.dart';
import 'package:stride/features/rewards/domain/unlocks.dart';
import 'package:stride/features/rewards/presentation/rewards_widgets.dart';
import 'package:stride/theme/app_theme.dart';

/// Shows every unlock from one run in a single sheet, one at a time: the
/// level-up first, then badges in catalogue order.
Future<void> showCelebration(BuildContext context, Unlocks unlocks) {
  if (unlocks.isEmpty) return Future.value();
  HapticFeedback.heavyImpact();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => CelebrationSheet(unlocks: unlocks),
  );
}

class CelebrationSheet extends StatefulWidget {
  final Unlocks unlocks;
  const CelebrationSheet({super.key, required this.unlocks});

  @override
  State<CelebrationSheet> createState() => _CelebrationSheetState();
}

class _CelebrationSheetState extends State<CelebrationSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _confetti =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.of(context).disableAnimations) _confetti.forward();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  bool get _isLevelStep => widget.unlocks.newLevel != null && _index == 0;

  BadgeId get _badge => widget.unlocks.badges[_index - (widget.unlocks.newLevel != null ? 1 : 0)];

  void _next() {
    if (_index + 1 >= widget.unlocks.count) {
      Navigator.of(context).pop();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _index++);
    _confetti.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    final total = widget.unlocks.count;
    final level = widget.unlocks.newLevel;

    final String title;
    final String subtitle;
    final Widget art;
    if (_isLevelStep) {
      title = 'level $level!';
      subtitle = 'Moop is growing with every run.';
      art = Moop(size: 130, mood: MoopMood.excited, growth: Levels.growthFor(level!));
    } else {
      final def = badgeDef(_badge);
      title = badgeHeadline(_badge);
      subtitle = def.description;
      art = SizedBox(width: 130, child: BadgeTile(id: _badge, earned: true));
    }

    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(
                    progress: _confetti.value,
                    colors: [c.butter, c.blush, c.sky, c.sage, c.coral],
                    outline: c.outline,
                    seed: _index,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    _isLevelStep ? 'LEVEL UP' : 'NEW BADGE',
                    style: text.labelMedium?.copyWith(letterSpacing: 2),
                  ),
                ),
                const SizedBox(height: 16),
                Center(child: KeyedSubtree(key: ValueKey(_index), child: art)),
                const SizedBox(height: 18),
                Text(title, style: text.displaySmall, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(subtitle, style: text.bodyLarge?.copyWith(color: c.inkMuted), textAlign: TextAlign.center),
                const SizedBox(height: 22),
                if (total > 1) ...[
                  Text('${_index + 1} OF $total', style: text.labelSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                ],
                PrimaryButton(
                  text: _index + 1 < total ? 'Next' : 'Nice!',
                  color: c.butter,
                  onPressed: _next,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A one-shot burst of outlined pastel confetti falling from the top.
class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;
  final Color outline;
  final int seed;

  _ConfettiPainter({required this.progress, required this.colors, required this.outline, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final random = math.Random(seed * 7919 + 17);
    final fade = progress > 0.75 ? (1 - progress) / 0.25 : 1.0;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = outline.withValues(alpha: fade);
    for (var i = 0; i < 36; i++) {
      final x0 = random.nextDouble() * size.width;
      final drift = (random.nextDouble() - 0.5) * 80;
      final speed = 0.6 + random.nextDouble() * 0.6;
      final spin = (random.nextDouble() - 0.5) * 10;
      // Confetti stays in the top half, clear of the title and text.
      final y = -20 + progress * speed * size.height * 0.5;
      final x = x0 + drift * progress;
      final rect = Rect.fromCenter(center: Offset.zero, width: 10, height: 6);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin * progress);
      canvas.drawRect(rect, Paint()..color = colors[i % colors.length].withValues(alpha: fade));
      canvas.drawRect(rect, stroke);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress || old.seed != seed;
}
