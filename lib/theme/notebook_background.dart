import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stride/theme/app_theme.dart';

/// Hand-drawn maths-notebook paper behind a screen: a slightly wobbly grid,
/// a faint margin line and a few ink doodles near the edges that bob gently.
///
/// The grid is static (drawn once per size, isolated by a RepaintBoundary);
/// only the small doodle layer animates. [seed] varies the doodles between
/// screens so each page feels like a different sheet.
class NotebookBackground extends StatefulWidget {
  final Widget child;
  final int seed;
  final int doodles;
  final bool margin;

  const NotebookBackground({
    super.key,
    required this.child,
    this.seed = 1,
    this.doodles = 4,
    this.margin = true,
  });

  @override
  State<NotebookBackground> createState() => _NotebookBackgroundState();
}

class _NotebookBackgroundState extends State<NotebookBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(seconds: 7));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.of(context).disableAnimations;
    if (still) {
      _bob.stop();
    } else if (!_bob.isAnimating) {
      _bob.repeat();
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: c.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _GridPainter(
                  line: c.outline.withValues(alpha: dark ? 0.07 : 0.06),
                  major: c.outline.withValues(alpha: dark ? 0.12 : 0.10),
                  margin: widget.margin ? c.coral.withValues(alpha: dark ? 0.35 : 0.30) : null,
                ),
              ),
            ),
          ),
          if (widget.doodles > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _bob,
                    builder: (context, _) => CustomPaint(
                      painter: _DoodlePainter(
                        seed: widget.seed,
                        count: widget.doodles,
                        phase: _bob.value,
                        ink: c.outline.withValues(alpha: dark ? 0.45 : 0.55),
                        fills: [c.butter, c.blush, c.sky, c.sage],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

/// A pen line from [a] to [b] with a small, fixed wobble.
Path _wobblyLine(Offset a, Offset b, math.Random r, {double amp = 0.7, double step = 34}) {
  final length = (b - a).distance;
  final dir = (b - a) / length;
  final normal = Offset(-dir.dy, dir.dx);
  final drift = (r.nextDouble() - 0.5) * 1.2; // whole line very slightly off-true
  final path = Path()..moveTo(a.dx, a.dy);
  for (var d = step; d < length + step; d += step) {
    final t = math.min(d, length);
    final wobble = (r.nextDouble() - 0.5) * 2 * amp + drift * (t / length);
    final p = a + dir * t + normal * wobble;
    path.lineTo(p.dx, p.dy);
  }
  return path;
}

class _GridPainter extends CustomPainter {
  static const double cell = 22;
  final Color line;
  final Color major;
  final Color? margin;

  _GridPainter({required this.line, required this.major, this.margin});

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(42);
    Paint pen(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    var i = 0;
    for (var x = cell; x < size.width; x += cell, i++) {
      final isMajor = i % 5 == 4;
      canvas.drawPath(
        _wobblyLine(Offset(x, 0), Offset(x, size.height), r),
        pen(isMajor ? major : line, isMajor ? 1.3 : 1.0),
      );
    }
    i = 0;
    for (var y = cell; y < size.height; y += cell, i++) {
      final isMajor = i % 5 == 4;
      canvas.drawPath(
        _wobblyLine(Offset(0, y), Offset(size.width, y), r),
        pen(isMajor ? major : line, isMajor ? 1.3 : 1.0),
      );
    }
    if (margin != null) {
      canvas.drawPath(_wobblyLine(const Offset(12, 0), Offset(12, size.height), r, amp: 1.0), pen(margin!, 1.6));
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.line != line || old.major != major || old.margin != margin;
}

enum _Doodle { star, squiggle, scribble, plus, arrow }

class _DoodlePainter extends CustomPainter {
  final int seed;
  final int count;
  final double phase;
  final Color ink;
  final List<Color> fills;

  _DoodlePainter({required this.seed, required this.count, required this.phase, required this.ink, required this.fills});

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(seed * 7919);
    final pen = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < count; i++) {
      // Keep doodles in the side gutters so they peek out around the cards.
      final leftSide = i.isEven;
      final x = size.width * (leftSide ? 0.03 + r.nextDouble() * 0.10 : 0.87 + r.nextDouble() * 0.10);
      final y = size.height * (0.08 + (i + r.nextDouble()) / count * 0.84);
      final kind = _Doodle.values[(seed + i) % _Doodle.values.length];
      final t = (phase + i / count) * 2 * math.pi;
      final bob = math.sin(t) * 3;
      final tilt = math.sin(t + 1) * 0.08;
      final fill = Paint()..color = fills[(seed + i) % fills.length];

      canvas.save();
      canvas.translate(x, y + bob);
      canvas.rotate(tilt + (r.nextDouble() - 0.5) * 0.6);
      final dr = math.Random(seed * 31 + i);
      switch (kind) {
        case _Doodle.star:
          final star = Path();
          for (var k = 0; k < 10; k++) {
            final rad = k.isEven ? 11.0 : 4.5;
            final a = -math.pi / 2 + k * math.pi / 5;
            final p = Offset(math.cos(a), math.sin(a)) * (rad + (dr.nextDouble() - 0.5));
            if (k == 0) {
              star.moveTo(p.dx, p.dy);
            } else {
              star.lineTo(p.dx, p.dy);
            }
          }
          star.close();
          canvas.drawPath(star, fill);
          canvas.drawPath(star, pen);
        case _Doodle.squiggle:
          final wave = Path()..moveTo(-16, 0);
          for (var k = 1; k <= 16; k++) {
            final px = -16 + k * 2.0;
            wave.lineTo(px, math.sin(k / 16 * 3 * math.pi) * 4 + (dr.nextDouble() - 0.5));
          }
          canvas.drawPath(wave, pen);
        case _Doodle.scribble:
          final loop = Path();
          for (var k = 0; k <= 40; k++) {
            final a = k / 40 * 2 * math.pi * 1.15;
            final rad = 8 + (dr.nextDouble() - 0.5) * 1.6 + k * 0.05;
            final p = Offset(math.cos(a), math.sin(a)) * rad;
            if (k == 0) {
              loop.moveTo(p.dx, p.dy);
            } else {
              loop.lineTo(p.dx, p.dy);
            }
          }
          canvas.drawCircle(Offset.zero, 6, fill);
          canvas.drawPath(loop, pen);
        case _Doodle.plus:
          canvas.drawLine(const Offset(-7, 0.5), const Offset(7, -0.5), pen);
          canvas.drawLine(const Offset(-0.5, -7), const Offset(0.5, 7), pen);
        case _Doodle.arrow:
          final shaft = Path()
            ..moveTo(-12, 4)
            ..quadraticBezierTo(-2, -6, 10, -2);
          canvas.drawPath(shaft, pen);
          canvas.drawLine(const Offset(10, -2), const Offset(4, -6), pen);
          canvas.drawLine(const Offset(10, -2), const Offset(5, 3), pen);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter old) => old.phase != phase || old.ink != ink || old.seed != seed;
}
