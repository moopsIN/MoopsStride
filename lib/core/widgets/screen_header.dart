import 'package:flutter/material.dart';
import 'package:stride/theme/app_theme.dart';
import 'package:stride/theme/brutal_card.dart';

/// Top of every secondary screen: outlined back button and a lowercase
/// Fraunces title, in place of a Material app bar.
class ScreenHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const ScreenHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          if (canPop) ...[
            BrutalCard(
              width: 44,
              height: 44,
              borderRadius: 22,
              shadow: 3,
              color: c.surface,
              onTap: () => Navigator.of(context).maybePop(),
              child: Icon(Icons.arrow_back_rounded, color: c.ink, size: 22),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.displaySmall, overflow: TextOverflow.ellipsis),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
