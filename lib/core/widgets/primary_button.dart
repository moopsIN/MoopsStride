import 'package:flutter/material.dart';
import 'package:stride/theme/app_theme.dart';
import 'package:stride/theme/brutal_card.dart';

/// Full-width neo-brutalist button that sinks into its shadow when pressed.
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isLoading;
  /// Defaults to the brand colour; pass a pastel for secondary actions.
  final Color? color;
  final Color? foregroundColor;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final bg = color ?? c.brand;
    final fg = foregroundColor ?? (color == null ? c.onBrand : c.onPastel);

    return Padding(
      padding: const EdgeInsets.only(right: Brutal.shadow, bottom: Brutal.shadow),
      child: Pressable(
        onTap: isLoading ? null : onPressed,
        shadow: Brutal.shadow,
        builder: (context, shadow) => Container(
          height: 58,
          alignment: Alignment.center,
          decoration: Brutal.box(c, color: bg, radius: Brutal.radiusSmall, shadow: shadow),
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: fg),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      text,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg, fontSize: 16),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
