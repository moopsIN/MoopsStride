import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stride/theme/app_theme.dart';
import 'package:stride/theme/brutal_card.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 100,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      width: width,
      height: height,
      borderRadius: borderRadius,
      color: context.stride.surfaceAlt,
      shadow: 0,
      child: const SizedBox.expand(),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1500.ms, color: Colors.white24)
        .fadeIn(duration: 500.ms);
  }
}
