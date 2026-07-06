import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigmaX;
  final double blurSigmaY;
  final Color backgroundColor;
  final Color borderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.blurSigmaX = 10.0,
    this.blurSigmaY = 10.0,
    this.backgroundColor = const Color(0x1AFFFFFF), // ~10% white by default
    this.borderColor = const Color(0x33FFFFFF), // ~20% white border by default
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Determine colors based on brightness if using standard defaults, to ensure visibility in light mode
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBgColor = backgroundColor == const Color(0x1AFFFFFF) && !isDark 
        ? const Color(0x1A000000) 
        : backgroundColor;
    final effectiveBorderColor = borderColor == const Color(0x33FFFFFF) && !isDark 
        ? const Color(0x33000000) 
        : borderColor;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: effectiveBorderColor,
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1), // Slightly smaller to fit inside border
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigmaX, sigmaY: blurSigmaY),
          child: Container(
            color: effectiveBgColor,
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
