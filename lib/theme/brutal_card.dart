import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stride/theme/app_theme.dart';

/// The basic neo-brutalist block: outlined, hard shadow, one flat colour.
/// With [onTap] it becomes pressable and sinks into its shadow while held.
class BrutalCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double borderRadius;
  final double shadow;
  final VoidCallback? onTap;

  const BrutalCard({
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius = Brutal.radius,
    this.shadow = Brutal.shadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Pressable(
      onTap: onTap,
      shadow: shadow,
      builder: (context, shadowNow) => Container(
        width: width,
        height: height,
        padding: padding,
        decoration: Brutal.box(context.stride, color: color, radius: borderRadius, shadow: shadowNow),
        child: child,
      ),
    );
    // Reserve the shadow's space so neighbours don't overlap it.
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.only(right: shadow, bottom: shadow),
        child: card,
      ),
    );
  }
}

/// Shared press behaviour: while held, the child moves by the shadow offset
/// and its shadow collapses, so it looks physically pushed in.
class Pressable extends StatefulWidget {
  final VoidCallback? onTap;
  final double shadow;
  final Widget Function(BuildContext context, double shadow) builder;

  const Pressable({super.key, required this.onTap, required this.shadow, required this.builder});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (widget.onTap != null && _down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    // Snap in fast; on release, spring back with a tiny overshoot so the
    // block feels physically pushed and let go. Position and shadow come
    // from the same animated value so the shadow never detaches.
    final content = TweenAnimationBuilder<double>(
      tween: Tween(end: _down ? widget.shadow : 0.0),
      duration: Duration(milliseconds: _down ? 60 : 420),
      curve: _down ? Curves.easeOut : const ElasticOutCurve(0.55),
      builder: (context, offset, _) => Transform.translate(
        offset: Offset(offset, offset),
        child: widget.builder(context, math.max(0, widget.shadow - offset)),
      ),
    );
    if (widget.onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap!();
      },
      child: content,
    );
  }
}

/// Small outlined label, e.g. a status or count.
class BrutalPill extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;

  const BrutalPill({super.key, required this.text, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final fg = textOn(color ?? c.butter);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: Brutal.box(c, color: color ?? c.butter, radius: Brutal.radiusPill, shadow: 0)
          .copyWith(border: Border.all(color: c.outline, width: 2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
          ],
          Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
        ],
      ),
    );
  }
}
