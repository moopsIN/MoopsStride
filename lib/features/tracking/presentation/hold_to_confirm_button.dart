import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A circular button that fires [onConfirmed] only after being held for
/// [holdDuration]. A ring fills while held and drains if released early, so
/// a stray tap can never trigger it.
class HoldToConfirmButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final double size;
  final Duration holdDuration;
  final VoidCallback onConfirmed;

  const HoldToConfirmButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onConfirmed,
    this.iconColor = Colors.white,
    this.size = 88,
    this.holdDuration = const Duration(milliseconds: 1000),
  });

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
    reverseDuration: const Duration(milliseconds: 250),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onConfirmed();
        _progress.value = 0;
      }
    });

  void _start() {
    HapticFeedback.selectionClick();
    _progress.forward();
  }

  void _cancel() {
    if (_progress.isAnimating && _progress.status == AnimationStatus.forward) {
      _progress.reverse();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringSize = widget.size + 14;
    // Listener rather than GestureDetector: reacts on pointer-down with no
    // gesture-arena delay, and always sees the release.
    return Listener(
      onPointerDown: (_) => _start(),
      onPointerUp: (_) => _cancel(),
      onPointerCancel: (_) => _cancel(),
      child: SizedBox(
        width: ringSize,
        height: ringSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _progress,
              builder: (context, _) => SizedBox(
                width: ringSize,
                height: ringSize,
                child: CircularProgressIndicator(
                  value: _progress.value,
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  color: widget.color,
                  backgroundColor: widget.color.withValues(alpha: 0.18),
                ),
              ),
            ),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.35),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(widget.icon, size: widget.size * 0.4, color: widget.iconColor),
            ),
          ],
        ),
      ),
    );
  }
}
