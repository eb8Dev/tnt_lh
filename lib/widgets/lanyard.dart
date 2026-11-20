import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// A card hanging from a strap: it drops in and swings into place, sways in
/// a light breeze, can be dragged and thrown, and flips over on a tap.
/// Native take on React Bits' Lanyard, in 2D physics with a 3D flip.
class Lanyard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final Size cardSize;
  final Color strapColor;
  final Color strapAccent;
  final double strapLength; // from the top of the box to the card's clip
  final bool intro;

  const Lanyard({
    super.key,
    required this.front,
    required this.back,
    this.cardSize = const Size(230, 330),
    this.strapColor = const Color(0xFF1C3A29),
    this.strapAccent = const Color(0xFFA9BCA4),
    this.strapLength = 150,
    this.intro = true,
  });

  @override
  State<Lanyard> createState() => _LanyardState();
}

class _LanyardState extends State<Lanyard> with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  Duration _last = Duration.zero;
  double _time = 0;

  // A pendulum: the strap swings at angle [_theta] from straight down
  // (positive to the right) with stretch [_r], and the card hangs from its
  // clip at its own angle [_alpha], springing back in line with the strap.
  double _theta = 0, _omega = 0;
  double _r = 0, _rv = 0;
  double _alpha = 0, _alphaV = 0;

  // Dragging: where on the card it was grabbed, and where the finger is.
  Offset? _grab;
  Offset? _finger;
  bool _reduce = false;
  bool _flipped = false;

  double get _halfH => widget.cardSize.height / 2;
  double get _rest => widget.strapLength;

  @override
  void initState() {
    super.initState();
    _r = _rest;
    if (widget.intro) {
      // Swung up to the right, card trailing: it drops in and swings home.
      _theta = 1.25;
      _alpha = 1.9;
    }
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.of(context).disableAnimations;
    if (_reduce) {
      _theta = _omega = _alpha = _alphaV = _rv = 0;
      _r = _rest;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _flip.dispose();
    super.dispose();
  }

  /// The clip (top centre of the card), relative to the anchor.
  Offset get _clip => Offset(math.sin(_theta), math.cos(_theta)) * _r;

  /// The card's centre, relative to the anchor.
  Offset get _centre =>
      _clip + Offset(math.sin(_alpha), math.cos(_alpha)) * _halfH;

  void _tick(Duration now) {
    final dt = math.min(1 / 30, (now - _last).inMicroseconds / 1e6);
    _last = now;
    if (dt <= 0) return;
    _time += dt;
    const steps = 4;
    for (var i = 0; i < steps; i++) {
      _step(dt / steps);
    }
    setState(() {});
  }

  void _step(double h) {
    if (_finger != null && _grab != null) {
      // Held: the card follows the finger and the strap follows the card.
      final centre = _finger! - _grab!;
      _alphaV += (-(_alpha - _theta) * 60 - _alphaV * 10) * h;
      _alpha += _alphaV * h;
      final clip = centre - Offset(math.sin(_alpha), math.cos(_alpha)) * _halfH;
      final r = clip.distance.clamp(_rest * 0.3, _rest * 2.2);
      final theta = math.atan2(clip.dx, clip.dy);
      // Remember how fast it is moving, for the throw.
      _omega = _omega * 0.7 + _wrap(theta - _theta) / h * 0.3;
      _rv = _rv * 0.7 + (r - _r) / h * 0.3;
      _theta = theta;
      _r = r;
      return;
    }

    const g = 2200.0;
    final breeze = _reduce
        ? 0.0
        : (math.sin(_time * 0.8) * 0.7 + math.sin(_time * 2.1 + 1.3) * 0.3) *
              0.35;
    final reach = _r + _halfH * 0.8;

    // Swing.
    final thetaAcc =
        (-g * math.sin(_theta) - 2 * _rv * _omega) / reach -
        1.4 * _omega +
        breeze;
    // Strap stretch: a stiff, well damped spring with gravity along it.
    final rAcc = -260 * (_r - _rest) - 24 * _rv + g * math.cos(_theta) * 0.02;
    // Card tilt: pulled in line with the strap, and lagging the swing.
    final alphaAcc =
        -38 * _wrap(_alpha - _theta) - 4.2 * _alphaV - thetaAcc * 0.4;

    _omega += thetaAcc * h;
    _rv += rAcc * h;
    _alphaV += alphaAcc * h;
    _omega = _omega.clamp(-14.0, 14.0);
    _theta += _omega * h;
    _r += _rv * h;
    _alpha += _alphaV * h;
  }

  static double _wrap(double a) {
    while (a > math.pi) {
      a -= 2 * math.pi;
    }
    while (a < -math.pi) {
      a += 2 * math.pi;
    }
    return a;
  }

  void _toggleFlip() {
    HapticFeedback.selectionClick();
    _flipped = !_flipped;
    _flipped ? _flip.forward() : _flip.reverse();
    // A little kick, like flipping a real badge.
    if (!_reduce) _alphaV += _flipped ? 4 : -4;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final anchor = Offset(box.maxWidth / 2, 0);
        final clip = _clip;
        final centre = _centre;
        final size = widget.cardSize;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _StrapPainter(
                  from: anchor,
                  to: anchor + clip,
                  slack: math.max(0, _rest - clip.distance),
                  color: widget.strapColor,
                  accent: widget.strapAccent,
                  angle: -_alpha,
                ),
              ),
            ),
            Positioned(
              left: anchor.dx + centre.dx - size.width / 2,
              top: anchor.dy + centre.dy - size.height / 2,
              width: size.width,
              height: size.height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleFlip,
                onPanStart: _reduce
                    ? null
                    : (d) {
                        _finger = d.globalPosition;
                        _grab = d.globalPosition - _centre;
                      },
                onPanUpdate: _reduce
                    ? null
                    : (d) {
                        _finger = d.globalPosition;
                      },
                onPanEnd: _reduce
                    ? null
                    : (d) {
                        // Throw: the finger's speed across the strap becomes swing.
                        final v = d.velocity.pixelsPerSecond;
                        final across = Offset(
                          math.cos(_theta),
                          -math.sin(_theta),
                        );
                        _omega =
                            ((v.dx * across.dx + v.dy * across.dy) /
                                    (_r + _halfH))
                                .clamp(-12.0, 12.0);
                        _finger = null;
                        _grab = null;
                      },
                child: Transform.rotate(
                  angle: -_alpha,
                  child: AnimatedBuilder(
                    animation: _flip,
                    builder: (_, _) {
                      final t = Curves.easeInOutBack
                          .transform(_flip.value)
                          .clamp(-0.1, 1.1);
                      final showBack = t > 0.5;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0014)
                          ..rotateY(math.pi * t),
                        child: showBack
                            ? Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.rotationY(math.pi),
                                child: _CardFace(child: widget.back),
                              )
                            : _CardFace(child: widget.front),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The card's body: rounded, with a slot for the clip and a soft shadow.
class _CardFace extends StatelessWidget {
  final Widget child;
  const _CardFace({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(22), child: child),
    );
  }
}

/// The strap: a woven band sagging when slack, with a metal clip at the card.
class _StrapPainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final double slack;
  final Color color;
  final Color accent;
  final double angle;
  _StrapPainter({
    required this.from,
    required this.to,
    required this.slack,
    required this.color,
    required this.accent,
    required this.angle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final mid = Offset.lerp(from, to, 0.5)!;
    final sag = Offset(slack * 0.35, slack * 0.8);
    final path = Path()
      ..moveTo(from.dx, from.dy - 40)
      ..lineTo(from.dx, from.dy)
      ..quadraticBezierTo(mid.dx + sag.dx, mid.dy + sag.dy, to.dx, to.dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20,
    );
    // Woven stitching down both edges.
    for (final edge in [-7.0, 7.0]) {
      final metrics = path.computeMetrics();
      for (final m in metrics) {
        for (double d = 0; d < m.length; d += 10) {
          final t = m.getTangentForOffset(d);
          if (t == null) continue;
          final n = Offset(-t.vector.dy, t.vector.dx);
          final a = t.position + n * edge;
          final b = a + t.vector * 5;
          canvas.drawLine(
            a,
            b,
            Paint()
              ..color = accent.withValues(alpha: 0.55)
              ..strokeWidth = 1.4,
          );
        }
      }
    }

    // The clip.
    canvas.save();
    canvas.translate(to.dx, to.dy);
    canvas.rotate(angle);
    final clip = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-17, -22, 34, 26),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      clip,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE9EBEF), Color(0xFF9EA3AC), Color(0xFFDDE0E5)],
        ).createShader(clip.outerRect),
    );
    canvas.drawCircle(
      const Offset(0, 6),
      7,
      Paint()
        ..color = const Color(0xFFB9BDC5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StrapPainter old) =>
      old.from != from ||
      old.to != to ||
      old.slack != slack ||
      old.angle != angle;
}
