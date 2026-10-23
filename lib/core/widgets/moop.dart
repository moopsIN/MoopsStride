import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Moop's expressions, mirroring the mascot on moops.in.
enum MoopMood { idle, happy, excited, sleepy, shocked }

/// Moop, the Moops mascot, drawn from the same geometry as the moops.in SVG
/// (200 × 230 viewBox) so it stays on-brand at any size.
///
/// With [animate], Moop breathes, blinks and sways its sprout. With
/// [running], its legs and arms swing in a stride cycle and it bobs.
class Moop extends StatefulWidget {
  final double size;
  final MoopMood mood;
  final bool animate;
  final bool running;
  /// How grown-up Moop is (from the runner's level): 0 sprout, 1 bushy
  /// sprout, 2 flower, 3 flower and crown.
  final int growth;

  const Moop({
    super.key,
    this.size = 120,
    this.mood = MoopMood.idle,
    this.animate = true,
    this.running = false,
    this.growth = 0,
  });

  @override
  State<Moop> createState() => _MoopState();
}

class _MoopState extends State<Moop> with TickerProviderStateMixin {
  late final AnimationController _idle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));
  late final AnimationController _stride =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  Timer? _blinkTimer;
  double _blink = 0;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(Moop old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate || old.running != widget.running) _sync();
  }

  void _sync() {
    if (widget.animate) {
      if (!_idle.isAnimating) _idle.repeat();
      _scheduleBlink();
    } else {
      _idle.stop();
      _blinkTimer?.cancel();
    }
    if (widget.running) {
      if (!_stride.isAnimating) _stride.repeat();
    } else {
      _stride.stop();
      _stride.value = 0;
    }
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(Duration(milliseconds: 2600 + _random.nextInt(2400)), () async {
      if (!mounted) return;
      setState(() => _blink = 1);
      await Future<void>.delayed(const Duration(milliseconds: 110));
      if (!mounted) return;
      setState(() => _blink = 0);
      _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _idle.dispose();
    _stride.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: widget.size,
      height: widget.size * MoopPainter.viewHeight / MoopPainter.viewWidth,
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _stride]),
        builder: (context, _) => CustomPaint(
          painter: MoopPainter(
            mood: widget.mood,
            palette: dark ? MoopPalette.dark : MoopPalette.light,
            idlePhase: _idle.value,
            stridePhase: widget.running ? _stride.value : null,
            blink: _blink,
            growth: widget.growth,
          ),
        ),
      ),
    );
  }
}

@immutable
class MoopPalette {
  final Color body;
  final Color limb;
  final Color eye;

  const MoopPalette({required this.body, required this.limb, required this.eye});

  static const light = MoopPalette(body: Color(0xFF5C7A38), limb: Color(0xFF3F5527), eye: Color(0xFF10130B));
  static const dark = MoopPalette(body: Color(0xFF6F833F), limb: Color(0xFFB3C77A), eye: Color(0xFF080A06));
}

class MoopPainter extends CustomPainter {
  static const double viewWidth = 200;
  static const double viewHeight = 230;

  static const _leafLeft = Color(0xFF8CC063);
  static const _leafRight = Color(0xFFA3D17A);
  static const _blushColor = Color(0xFFF7A1B4);
  static const _shadowColor = Color(0x244A3E18); // rgb(74 62 24 / 0.14)
  static const _petal = Color(0xFFF4A3B5);
  static const _butter = Color(0xFFFFE58A);
  static const _ink = Color(0xFF211F1B);

  final MoopMood mood;
  final MoopPalette palette;
  /// 0..1 loop driving breathing and sprout sway.
  final double idlePhase;
  /// 0..1 loop of the stride cycle, or null when standing.
  final double? stridePhase;
  /// 1 = eyes closed.
  final double blink;
  /// 0..3, see [Moop.growth].
  final int growth;

  MoopPainter({
    required this.mood,
    required this.palette,
    this.idlePhase = 0,
    this.stridePhase,
    this.blink = 0,
    this.growth = 0,
  });

  Paint _fill(Color c) => Paint()..color = c..isAntiAlias = true;
  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  void _rotated(Canvas canvas, Offset pivot, double radians, void Function() draw) {
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(radians);
    canvas.translate(-pivot.dx, -pivot.dy);
    draw();
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / viewWidth, size.height / viewHeight);

    final breathe = math.sin(idlePhase * 2 * math.pi);
    final stride = stridePhase == null ? null : math.sin(stridePhase! * 2 * math.pi);
    // Running: a bob on each footfall (twice per cycle) and a slight lean.
    final bob = stride == null ? 0.0 : -(math.sin(stridePhase! * 4 * math.pi).abs()) * 7;
    final lean = stride == null ? 0.0 : 0.07;

    // Ground shadow shrinks as Moop bobs up.
    final shadowScale = 1 + bob / 60;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 219), width: 104 * shadowScale, height: 12 * shadowScale),
      _fill(_shadowColor),
    );

    canvas.save();
    canvas.translate(0, bob);
    _rotated(canvas, const Offset(100, 200), lean, () {
      _legs(canvas, stride);
      _arms(canvas, stride);
      _bodyGroup(canvas, breathe);
    });
    canvas.restore();
    canvas.restore();
  }

  void _legs(Canvas canvas, double? stride) {
    final swing = (stride ?? 0) * 0.5;
    final limb = _stroke(palette.limb, 6);
    final foot = _fill(palette.limb);
    _rotated(canvas, const Offset(86, 186), swing, () {
      canvas.drawLine(const Offset(85, 190), const Offset(83, 203), limb);
      canvas.drawOval(Rect.fromCenter(center: const Offset(79, 207), width: 25, height: 15), foot);
    });
    _rotated(canvas, const Offset(114, 186), -swing, () {
      canvas.drawLine(const Offset(115, 190), const Offset(117, 203), limb);
      canvas.drawOval(Rect.fromCenter(center: const Offset(121, 207), width: 25, height: 15), foot);
    });
  }

  void _arms(Canvas canvas, double? stride) {
    double left = 0, right = 0;
    switch (mood) {
      case MoopMood.excited:
        left = 95 * math.pi / 180;
        right = -95 * math.pi / 180;
      case MoopMood.shocked:
        left = 45 * math.pi / 180;
        right = -45 * math.pi / 180;
      default:
        break;
    }
    if (stride != null) {
      // Arms swing opposite to the legs.
      left += -stride * 0.6;
      right += -stride * 0.6;
    }
    final limb = _stroke(palette.limb, 6);
    final hand = _fill(palette.limb);
    _rotated(canvas, const Offset(36, 130), left, () {
      canvas.drawPath(Path()..moveTo(34, 132)..quadraticBezierTo(20, 140, 12, 154), limb);
      canvas.drawCircle(const Offset(12, 154), 6, hand);
    });
    _rotated(canvas, const Offset(164, 130), right, () {
      canvas.drawPath(Path()..moveTo(166, 132)..quadraticBezierTo(180, 140, 188, 154), limb);
      canvas.drawCircle(const Offset(188, 154), 6, hand);
    });
  }

  void _bodyGroup(Canvas canvas, double breathe) {
    canvas.save();
    // Breathe: squash/stretch from the feet.
    final sy = 1 + breathe * 0.018;
    final sx = 1 - breathe * 0.012;
    canvas.translate(100, 197);
    canvas.scale(sx, sy);
    canvas.translate(-100, -197);

    _sprout(canvas, breathe);

    final body = Path()
      ..moveTo(100, 50)
      ..cubicTo(151, 50, 177, 92, 178, 135)
      ..cubicTo(179, 177, 147, 197, 100, 197)
      ..cubicTo(53, 197, 21, 177, 22, 135)
      ..cubicTo(23, 92, 49, 50, 100, 50)
      ..close();
    canvas.drawPath(body, _fill(palette.body));

    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 168), width: 92, height: 46),
        _fill(Colors.white.withValues(alpha: 0.05)));
    final shine = _fill(Colors.white.withValues(alpha: 0.2));
    _rotated(canvas, const Offset(68, 82), -32 * math.pi / 180, () {
      canvas.drawOval(Rect.fromCenter(center: const Offset(68, 82), width: 44, height: 20), shine);
    });
    canvas.drawCircle(const Offset(92, 66), 4, shine);

    if (growth >= 3) _crown(canvas);
    _face(canvas);
    canvas.restore();
  }

  /// A small butter crown sitting on the head, around the sprout's stem.
  void _crown(Canvas canvas) {
    final crown = Path()
      ..moveTo(72, 66)
      ..lineTo(68, 40)
      ..lineTo(85, 53)
      ..lineTo(100, 32)
      ..lineTo(115, 53)
      ..lineTo(132, 40)
      ..lineTo(128, 66)
      ..close();
    canvas.drawPath(crown, _fill(_butter));
    canvas.drawPath(crown, _stroke(_ink, 3));
    final jewel = _fill(_petal);
    for (final x in const [86.0, 100.0, 114.0]) {
      canvas.drawCircle(Offset(x, 59), 3.4, jewel);
    }
  }

  void _sprout(Canvas canvas, double breathe) {
    final sway = mood == MoopMood.sleepy ? 18 * math.pi / 180 : breathe * 0.12;
    _rotated(canvas, const Offset(100, 54), sway, () {
      canvas.drawPath(Path()..moveTo(100, 54)..quadraticBezierTo(98, 44, 101, 36), _stroke(palette.limb, 4));
      canvas.drawPath(
        Path()
          ..moveTo(100.5, 38)
          ..cubicTo(89, 37, 82, 29, 84, 19)
          ..cubicTo(95, 19, 102, 27, 100.5, 38)
          ..close(),
        _fill(_leafLeft),
      );
      canvas.drawPath(
        Path()
          ..moveTo(101.5, 37)
          ..cubicTo(106, 28, 114, 24, 123, 25)
          ..cubicTo(121, 34, 111, 39, 101.5, 37)
          ..close(),
        _fill(_leafRight),
      );
      if (growth >= 1) {
        // A taller stem topped by a third, upright leaf: the sprout grows up.
        canvas.drawPath(Path()..moveTo(101, 36)..quadraticBezierTo(103, 26, 100, 16), _stroke(palette.limb, 3.5));
        canvas.drawPath(
          Path()
            ..moveTo(100, 18)
            ..cubicTo(94, 11, 95, 2, 103, -4)
            ..cubicTo(109, 4, 107, 13, 100, 18)
            ..close(),
          _fill(_leafRight),
        );
      }
      if (growth >= 2) _flower(canvas, const Offset(100, 12));
    });
  }

  void _flower(Canvas canvas, Offset center) {
    final petal = _fill(_petal);
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      canvas.drawCircle(center + Offset(math.cos(a), math.sin(a)) * 6.5, 5.2, petal);
    }
    canvas.drawCircle(center, 4.2, _fill(_butter));
  }

  void _face(Canvas canvas) {
    final eye = _fill(palette.eye);
    final eyeLine = _stroke(palette.eye, 5);

    switch (mood) {
      case MoopMood.happy:
      case MoopMood.excited:
        canvas.drawPath(Path()..moveTo(67, 121)..quadraticBezierTo(78, 105, 89, 121), eyeLine);
        canvas.drawPath(Path()..moveTo(111, 121)..quadraticBezierTo(122, 105, 133, 121), eyeLine);
      case MoopMood.sleepy:
        canvas.drawPath(Path()..moveTo(67, 116)..quadraticBezierTo(78, 127, 89, 116), eyeLine);
        canvas.drawPath(Path()..moveTo(111, 116)..quadraticBezierTo(122, 127, 133, 116), eyeLine);
      case MoopMood.idle:
      case MoopMood.shocked:
        final scale = mood == MoopMood.shocked ? 1.18 : 1.0;
        final openness = (1 - blink * 0.9);
        for (final cx in const [78.0, 122.0]) {
          canvas.save();
          canvas.translate(cx, 117);
          canvas.scale(scale, scale * openness);
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 21, height: 27), eye);
          if (blink < 0.5) {
            final glint = _fill(Colors.white);
            canvas.drawCircle(const Offset(4.5, -6.5), 4.2, glint);
            canvas.drawCircle(const Offset(-3.5, 6), 1.9, glint);
          }
          canvas.restore();
        }
    }

    final blush = _fill(_blushColor.withValues(alpha: 0.75));
    canvas.drawOval(Rect.fromCenter(center: const Offset(58, 137), width: 24, height: 13), blush);
    canvas.drawOval(Rect.fromCenter(center: const Offset(142, 137), width: 24, height: 13), blush);

    switch (mood) {
      case MoopMood.idle:
      case MoopMood.happy:
        canvas.drawPath(
          Path()
            ..moveTo(91, 137)
            ..quadraticBezierTo(95.5, 142.5, 100, 137)
            ..quadraticBezierTo(104.5, 142.5, 109, 137),
          _stroke(palette.eye, 3.6),
        );
      case MoopMood.excited:
        canvas.drawPath(
          Path()..moveTo(90, 135)..quadraticBezierTo(100, 151, 110, 135)..close(),
          eye,
        );
      case MoopMood.sleepy:
        canvas.drawOval(Rect.fromCenter(center: const Offset(100, 141), width: 5.5, height: 7), eye);
      case MoopMood.shocked:
        canvas.drawOval(Rect.fromCenter(center: const Offset(100, 141), width: 10, height: 13), eye);
    }
  }

  @override
  bool shouldRepaint(MoopPainter old) =>
      old.mood != mood ||
      old.palette != palette ||
      old.idlePhase != idlePhase ||
      old.stridePhase != stridePhase ||
      old.blink != blink ||
      old.growth != growth;
}
