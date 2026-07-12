import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The brand loader: a cup slowly brewing.
///
/// The liquid rises and settles with a live, sloshing surface, a band of crema
/// sits on top, and steam curls off it — while the colour drifts between the
/// cafe's sage and the bakery's terracotta, so the one loader speaks for both
/// brands instead of cross-fading two logos at each other.
///
/// Everything is painted on a single canvas (no assets), and it falls back to a
/// still cup when the OS asks for reduced motion.
class HouseOfFlavorsLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const HouseOfFlavorsLoader({super.key, this.size = 150.0, this.color});

  @override
  State<HouseOfFlavorsLoader> createState() => _HouseOfFlavorsLoaderState();
}

class _HouseOfFlavorsLoaderState extends State<HouseOfFlavorsLoader>
    with TickerProviderStateMixin {
  // The pour: liquid climbing, then settling back — the "working" beat.
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  // The surface ripple, deliberately out of step with the fill so the liquid
  // never looks like it's moving as one rigid block.
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  late final AnimationController _steam = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  // Sage (Teas n Trees) <-> terracotta (Little H).
  late final AnimationController _brand = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _fill.dispose();
    _wave.dispose();
    _steam.dispose();
    _brand.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_fill, _wave, _steam, _brand]),
        builder: (context, _) {
          final brew =
              widget.color ??
              Color.lerp(
                const Color(0xFF57733C), // Teas n Trees sage
                const Color(0xFF8C3414), // Little H terracotta
                Curves.easeInOut.transform(_brand.value),
              )!;

          return CustomPaint(
            painter: _BrewPainter(
              // A still, half-full cup when motion is unwelcome.
              fill: reduceMotion
                  ? 0.55
                  : 0.25 + 0.5 * Curves.easeInOutSine.transform(_fill.value),
              wave: reduceMotion ? 0 : _wave.value,
              steam: reduceMotion ? -1 : _steam.value,
              color: brew,
            ),
          );
        },
      ),
    );
  }
}

class _BrewPainter extends CustomPainter {
  /// 0..1 — how full the cup is.
  final double fill;

  /// 0..1 — phase of the surface ripple.
  final double wave;

  /// 0..1 — phase of the rising steam. Negative disables it.
  final double steam;

  final Color color;

  _BrewPainter({
    required this.fill,
    required this.wave,
    required this.steam,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;

    // Cup geometry: a gently tapered vessel, centred, sitting on a saucer.
    final cupTop = s * 0.34;
    final cupBottom = s * 0.78;
    final halfTop = s * 0.22;
    final halfBottom = s * 0.16;
    final cx = size.width / 2;

    final cup = Path()
      ..moveTo(cx - halfTop, cupTop)
      ..lineTo(cx - halfBottom, cupBottom - s * 0.05)
      ..quadraticBezierTo(
        cx - halfBottom,
        cupBottom,
        cx - halfBottom + s * 0.05,
        cupBottom,
      )
      ..lineTo(cx + halfBottom - s * 0.05, cupBottom)
      ..quadraticBezierTo(
        cx + halfBottom,
        cupBottom,
        cx + halfBottom,
        cupBottom - s * 0.05,
      )
      ..lineTo(cx + halfTop, cupTop)
      ..close();

    if (steam >= 0) _paintSteam(canvas, size, s, cx, cupTop);

    // Liquid, clipped to the inside of the cup.
    canvas.save();
    canvas.clipPath(cup);
    _paintLiquid(canvas, size, s, cx, cupTop, cupBottom);
    canvas.restore();

    // The cup itself, drawn over the liquid so the rim reads cleanly.
    canvas.drawPath(
      cup,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.022
        ..strokeJoin = StrokeJoin.round,
    );

    // Handle.
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(cx + halfTop + s * 0.01, cupTop + s * 0.14),
        radius: s * 0.085,
      ),
      -math.pi / 2.4,
      math.pi * 1.15,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.02
        ..strokeCap = StrokeCap.round,
    );

    // Saucer.
    final saucerY = cupBottom + s * 0.045;
    canvas.drawLine(
      Offset(cx - s * 0.26, saucerY),
      Offset(cx + s * 0.26, saucerY),
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.02
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintLiquid(
    Canvas canvas,
    Size size,
    double s,
    double cx,
    double cupTop,
    double cupBottom,
  ) {
    final innerTop = cupTop + s * 0.03;
    final surfaceY = cupBottom - (cupBottom - innerTop) * fill;

    // Two sine waves at different frequencies so the surface never looks like a
    // single mechanical ripple.
    final amp = s * 0.016;
    final path = Path()..moveTo(0, surfaceY);
    for (double x = 0; x <= size.width; x += 2) {
      final phase = (x / size.width) * 2 * math.pi;
      final y =
          surfaceY +
          math.sin(phase * 2 + wave * 2 * math.pi) * amp +
          math.sin(phase * 3.7 - wave * 2 * math.pi * 1.4) * amp * 0.45;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.9),
          ],
        ).createShader(Rect.fromLTWH(0, surfaceY, size.width, size.height)),
    );

    // A band of crema riding the surface.
    final crema = Path()..moveTo(0, surfaceY);
    for (double x = 0; x <= size.width; x += 2) {
      final phase = (x / size.width) * 2 * math.pi;
      final y =
          surfaceY +
          math.sin(phase * 2 + wave * 2 * math.pi) * amp +
          math.sin(phase * 3.7 - wave * 2 * math.pi * 1.4) * amp * 0.45;
      crema.lineTo(x, y);
    }
    canvas.drawPath(
      crema,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018,
    );
  }

  void _paintSteam(
    Canvas canvas,
    Size size,
    double s,
    double cx,
    double cupTop,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.016
      ..strokeCap = StrokeCap.round;

    for (int i = -1; i <= 1; i++) {
      // Each wisp is offset in phase so they don't pulse in lockstep.
      final t = (steam + i * 0.28) % 1.0;
      final baseX = cx + i * s * 0.11;
      final startY = cupTop - s * 0.02;
      final height = s * 0.26;

      final path = Path()..moveTo(baseX, startY);
      for (double u = 0; u <= 1; u += 0.05) {
        final y = startY - u * height - t * s * 0.06;
        final x = baseX + math.sin(u * math.pi * 2.2 + t * math.pi * 2) * s * 0.03;
        path.lineTo(x, y);
      }

      // Fade in as it leaves the cup, out as it dissipates.
      final opacity = (math.sin(t * math.pi)).clamp(0.0, 1.0) * 0.45;
      paint.color = color.withValues(alpha: opacity);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_BrewPainter old) =>
      old.fill != fill ||
      old.wave != wave ||
      old.steam != steam ||
      old.color != color;
}
