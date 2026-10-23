import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stride/theme/notebook_background.dart';
import 'package:stride/features/tracking/models/activity_model.dart';
import 'package:stride/features/rewards/domain/rewards_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stride/core/database/local_db.dart';
import 'package:stride/core/widgets/moop.dart';
import 'package:stride/features/auth/presentation/auth_screen.dart';
import 'package:stride/features/auth/providers/auth_provider.dart';
import 'package:stride/features/sync/presentation/sync_prompt_screen.dart';
import 'package:stride/features/tracking/presentation/tracking_screen.dart';
import 'package:stride/theme/app_theme.dart';

/// Moop strides in, leaves a dashed trail, stops with a happy hop, and the
/// wordmark lands. Routing is worked out in parallel; we leave once both the
/// animation and the route are ready.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));

  /// Moop runs until this point of the timeline, then stops and hops.
  static const double _arrive = 0.55;

  /// Returning runners see their grown-up Moop from the first frame they can.
  int _growth = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    _loadGrowth();
    final next = _resolveNext();
    if (reduceMotion) {
      _c.value = 1;
    } else {
      await _c.forward().orCancel.catchError((_) {});
    }
    final screen = await next;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 450),
    ));
  }

  Future<void> _loadGrowth() async {
    final runs = (await LocalDatabase.instance.getActivities()).map(ActivityModel.fromMap);
    final growth = RewardsEngine.compute(runs, DateTime.now()).moopGrowth;
    if (mounted && growth != _growth) setState(() => _growth = growth);
  }

  Future<Widget> _resolveNext() async {
    // Read providers before any await; the splash may be gone afterwards.
    final user = ref.read(authProvider);
    final hasCompletedOnboarding = await LocalDatabase.instance.getUserProfile() != null;
    if (hasCompletedOnboarding) return const TrackingScreen();
    if (user != null && mounted) return SyncPromptScreen.routeFor(ref, user.uid);
    return const AuthScreen();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _interval(double t, double begin, double end, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    final text = Theme.of(context).textTheme;
    const moopSize = 128.0;

    return Scaffold(
      backgroundColor: c.background,
      body: NotebookBackground(
        seed: 11,
        doodles: 3,
        child: LayoutBuilder(builder: (context, box) {
          final centerX = box.maxWidth / 2;
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final run = _interval(t, 0, _arrive);
              final moopCenterX = -moopSize + (centerX + moopSize) * run;
              final running = t < _arrive && t > 0;
              final hopT = _interval(t, _arrive, _arrive + 0.15, Curves.linear);
              final hop = math.sin(hopT * math.pi) * 18;
              final word = _interval(t, 0.5, 0.78, Curves.easeOutBack);
              final byline = _interval(t, 0.7, 0.92);
  
              return Stack(
                children: [
                  // Two calm brand shapes, neo-brutalist but orderly.
                  Positioned(
                    top: -90,
                    right: -70,
                    child: _Blob(color: c.butter, size: 230, round: true),
                  ),
                  Positioned(
                    bottom: -50,
                    left: -40,
                    child: Transform.rotate(angle: -0.25, child: _Blob(color: c.sky, size: 150)),
                  ),
                  Align(
                    alignment: const Alignment(0, -0.15),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: box.maxWidth,
                          height: moopSize * 1.3,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // The trail Moop leaves behind as it runs in.
                              Positioned(
                                left: 0,
                                bottom: 6,
                                child: CustomPaint(
                                  size: Size(math.max(0, moopCenterX - moopSize * 0.35), 4),
                                  painter: _TrailPainter(c.outline.withValues(alpha: 0.35)),
                                ),
                              ),
                              Positioned(
                                left: moopCenterX - moopSize / 2,
                                bottom: hop,
                                child: Moop(
                                  size: moopSize,
                                  running: running,
                                  growth: _growth,
                                  mood: t >= _arrive ? MoopMood.happy : MoopMood.idle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Opacity(
                          opacity: word.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, (1 - word) * 24),
                            child: Text(
                              'stride',
                              style: text.displayLarge?.copyWith(fontSize: 64, letterSpacing: -2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: byline,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: Brutal.box(c, color: c.blush, radius: Brutal.radiusPill, shadow: 3),
                            child: Text('BY MOOPS', style: text.labelMedium?.copyWith(color: c.onPastel, letterSpacing: 2)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        }),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  final bool round;

  const _Blob({required this.color, required this.size, this.round = false});

  @override
  Widget build(BuildContext context) {
    final c = context.stride;
    return Container(
      width: size,
      height: size,
      decoration: Brutal.box(c, color: color, radius: round ? size : 36, shadow: 6),
    );
  }
}

class _TrailPainter extends CustomPainter {
  final Color color;
  _TrailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const dash = 10.0, gap = 8.0;
    // Anchored at the left edge so dashes stay fixed on the ground and simply
    // appear behind Moop, rather than sliding along with it.
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 0, math.min(dash, size.width - x), size.height), const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) => old.color != color;
}
