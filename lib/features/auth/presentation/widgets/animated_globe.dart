import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

/// A dotted Earth that spins slowly, ringed by gold coins that orbit it.
/// Drawn entirely with a [CustomPainter] (no assets). Holds still when the
/// system asks for reduced motion.
class AnimatedGlobe extends StatefulWidget {
  const AnimatedGlobe({super.key, required this.size});

  final double size;

  @override
  State<AnimatedGlobe> createState() => _AnimatedGlobeState();
}

class _AnimatedGlobeState extends State<AnimatedGlobe>
    with SingleTickerProviderStateMixin {
  /// One full turn of the globe; the coins orbit a little faster.
  static const _period = Duration(seconds: 36);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(painter: _GlobePainter(_controller)),
      ),
    );
  }
}

class _Coin {
  const _Coin(this.symbol, this.phase);

  final String symbol;

  /// Where on the orbit the coin starts, in turns.
  final double phase;
}

class _GlobePainter extends CustomPainter {
  _GlobePainter(this._animation) : super(repaint: _animation);

  final Animation<double> _animation;

  static const _coins = [
    _Coin(r'$', 0.0),
    _Coin('€', 0.2),
    _Coin('₹', 0.4),
    _Coin('¥', 0.6),
    _Coin('£', 0.8),
    _Coin('₽', 1),
  ];

  /// Points on a Fibonacci sphere with a land flag, computed once.
  static final List<({double x, double y, double z, bool land})> _points =
      _buildPoints(1500);

  static List<({double x, double y, double z, bool land})> _buildPoints(int n) {
    final golden = math.pi * (3 - math.sqrt(5));
    return [
      for (var i = 0; i < n; i++)
        () {
          final y = 1 - 2 * (i + 0.5) / n;
          final r = math.sqrt(1 - y * y);
          final theta = golden * i;
          final x = math.cos(theta) * r;
          final z = math.sin(theta) * r;
          return (x: x, y: y, z: z, land: _isLand(x, y, z));
        }(),
    ];
  }

  /// A smooth pseudo-random field on the sphere, thresholded into continents.
  static bool _isLand(double x, double y, double z) {
    final v =
        math.sin(2.1 * x + 1.3) * math.cos(2.7 * y - 0.4) +
        math.sin(3.3 * z + 2.0 * x) * 0.8 +
        0.5 * math.sin(5 * x + 4 * y + 3 * z);
    return v > 0.45;
  }

  static const _tilt = 0.41; // ~23.5 degrees, like the real axis

  @override
  void paint(Canvas canvas, Size size) {
    final t = _animation.value;
    final c = size.center(Offset.zero);
    final radius = size.width * 0.3;
    final spin = t * 2 * math.pi;

    _paintCoins(canvas, c, radius, t, front: false);
    _paintGlobe(canvas, c, radius, spin);
    _paintCoins(canvas, c, radius, t, front: true);
  }

  void _paintGlobe(Canvas canvas, Offset c, double radius, double spin) {
    // Glow behind the sphere.
    canvas.drawCircle(
      c,
      radius * 1.25,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x553B82F6), Color(0x00000000)],
        ).createShader(Rect.fromCircle(center: c, radius: radius * 1.25)),
    );
    // The sphere body.
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.4),
          colors: [Color(0xFF1C3A6B), Color(0xFF0A1426)],
        ).createShader(Rect.fromCircle(center: c, radius: radius)),
    );

    final cosS = math.cos(spin);
    final sinS = math.sin(spin);
    final cosT = math.cos(_tilt);
    final sinT = math.sin(_tilt);

    final ocean = <Offset>[];
    final landNear = <Offset>[];
    final landFar = <Offset>[];
    for (final p in _points) {
      // Spin around the vertical axis, then tilt the axis toward the viewer.
      final x1 = p.x * cosS + p.z * sinS;
      final z1 = -p.x * sinS + p.z * cosS;
      final y2 = p.y * cosT - z1 * sinT;
      final z2 = p.y * sinT + z1 * cosT;
      if (z2 < 0) continue; // far side is hidden
      final o = Offset(c.dx + x1 * radius, c.dy - y2 * radius);
      if (!p.land) {
        ocean.add(o);
      } else if (z2 > 0.45) {
        landNear.add(o);
      } else {
        landFar.add(o);
      }
    }

    final dot = radius * 0.02;
    Paint dots(Color color) => Paint()
      ..color = color
      ..strokeWidth = dot * 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(
      PointMode.points,
      ocean,
      dots(const Color(0xFF2E5C9A).withValues(alpha: 0.35)),
    );
    canvas.drawPoints(
      PointMode.points,
      landFar,
      dots(const Color(0xFF4FB3A5).withValues(alpha: 0.55)),
    );
    canvas.drawPoints(
      PointMode.points,
      landNear,
      dots(const Color(0xFF9CF0C2)),
    );

    // Soft rim light.
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.02
        ..color = const Color(0xFF6FA2E0).withValues(alpha: 0.5),
    );
  }

  void _paintCoins(
    Canvas canvas,
    Offset c,
    double radius,
    double t, {
    required bool front,
  }) {
    final orbitX = radius * 1.55;
    final orbitY = radius * 0.5;
    const tilt = -0.35;
    final cosR = math.cos(tilt);
    final sinR = math.sin(tilt);

    for (final coin in _coins) {
      final a = (t * 1.5 + coin.phase) * 2 * math.pi;
      final depth = math.sin(a); // > 0: in front of the globe
      if ((depth > 0) != front) continue;
      final ox = math.cos(a) * orbitX;
      final oy = depth * orbitY;
      final p = Offset(
        c.dx + ox * cosR - oy * sinR,
        c.dy + ox * sinR + oy * cosR,
      );
      final scale = 0.8 + 0.3 * depth;
      _paintCoin(canvas, p, radius * 0.2 * scale, coin.symbol, depth);
    }
  }

  void _paintCoin(
    Canvas canvas,
    Offset p,
    double r,
    String symbol,
    double depth,
  ) {
    final rect = Rect.fromCircle(center: p, radius: r);
    canvas.drawCircle(
      p,
      r * 1.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFC94A).withValues(alpha: 0.28),
            const Color(0x00FFC94A),
          ],
        ).createShader(Rect.fromCircle(center: p, radius: r * 1.5)),
    );
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE08A), Color(0xFFE0A21B)],
        ).createShader(rect),
    );
    canvas.drawCircle(
      p,
      r * 0.78,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..color = const Color(0xFFB77A0A).withValues(alpha: 0.7),
    );
    final text = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          fontSize: r * 1.15,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF8A5A00),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, p - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(_GlobePainter oldDelegate) => false;
}
