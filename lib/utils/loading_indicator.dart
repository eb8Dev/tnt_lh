import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/providers/brand_provider.dart';

/// The brand loader — one idea, two personalities.
///
/// Both are a *vessel with something rising in it*, so they read as a family,
/// but each belongs to its own shop:
///
///  * **Teas n Trees** — a cup brewing: the liquid climbs and settles with a
///    live sloshing surface, crema on top, steam curling off it.
///  * **Little H** — dough proving: a scored boule swells and relaxes in its
///    bowl while flour drifts down around it.
///
/// It reads [brandProvider] itself, so it changes with the store without any
/// call site having to know. Pass [brand] to force one. Everything is painted
/// on a single canvas (no assets), and both fall still under reduced motion.
class HouseOfFlavorsLoader extends ConsumerStatefulWidget {
  final double size;
  final Color? color;

  /// 'teasntrees' | 'littleh'. Defaults to whichever store you're in.
  final String? brand;

  const HouseOfFlavorsLoader({
    super.key,
    this.size = 150.0,
    this.color,
    this.brand,
  });

  @override
  ConsumerState<HouseOfFlavorsLoader> createState() =>
      _HouseOfFlavorsLoaderState();
}

class _HouseOfFlavorsLoaderState extends ConsumerState<HouseOfFlavorsLoader>
    with TickerProviderStateMixin {
  static const _sage = Color(0xFF57733C); // Teas n Trees
  static const _terracotta = Color(0xFF8C3414); // Little H

  /// The main beat: liquid climbing, or dough proving.
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  /// Surface ripple / dough wobble — deliberately out of step with [_rise] so
  /// nothing ever moves as one rigid block.
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  /// Steam, or drifting flour.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _rise.dispose();
    _wave.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final brand = widget.brand ?? ref.watch(brandProvider);
    final isLittleH = brand == 'littleh';

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rise, _wave, _drift]),
        builder: (context, _) {
          final tint =
              widget.color ?? (isLittleH ? _terracotta : _sage);

          // Held mid-motion when the OS asks us not to animate.
          final rise = reduceMotion
              ? 0.55
              : Curves.easeInOutSine.transform(_rise.value);
          final wave = reduceMotion ? 0.0 : _wave.value;
          final drift = reduceMotion ? -1.0 : _drift.value;

          return CustomPaint(
            painter: isLittleH
                ? _ProofPainter(rise: rise, wobble: wave, flour: drift, color: tint)
                : _BrewPainter(
                    fill: 0.25 + 0.5 * rise,
                    wave: wave,
                    steam: drift,
                    color: tint,
                  ),
          );
        },
      ),
    );
  }
}

/* ─────────────────────────────  Teas n Trees  ───────────────────────────── */

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

    // A gently tapered vessel, centred, sitting on a saucer.
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

    if (steam >= 0) _paintSteam(canvas, s, cx, cupTop);

    canvas.save();
    canvas.clipPath(cup);
    _paintLiquid(canvas, size, s, cupTop, cupBottom);
    canvas.restore();

    // Drawn over the liquid so the rim reads cleanly.
    canvas.drawPath(
      cup,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.022
        ..strokeJoin = StrokeJoin.round,
    );

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

  /// Two sine waves at different frequencies, so the surface never looks like a
  /// single mechanical ripple.
  double _surfaceAt(double x, double width, double surfaceY, double amp) {
    final phase = (x / width) * 2 * math.pi;
    return surfaceY +
        math.sin(phase * 2 + wave * 2 * math.pi) * amp +
        math.sin(phase * 3.7 - wave * 2 * math.pi * 1.4) * amp * 0.45;
  }

  void _paintLiquid(
    Canvas canvas,
    Size size,
    double s,
    double cupTop,
    double cupBottom,
  ) {
    final innerTop = cupTop + s * 0.03;
    final surfaceY = cupBottom - (cupBottom - innerTop) * fill;
    final amp = s * 0.016;

    final body = Path()..moveTo(0, surfaceY);
    for (double x = 0; x <= size.width; x += 2) {
      body.lineTo(x, _surfaceAt(x, size.width, surfaceY, amp));
    }
    body
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      body,
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
      crema.lineTo(x, _surfaceAt(x, size.width, surfaceY, amp));
    }
    canvas.drawPath(
      crema,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018,
    );
  }

  void _paintSteam(Canvas canvas, double s, double cx, double cupTop) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.016
      ..strokeCap = StrokeCap.round;

    for (int i = -1; i <= 1; i++) {
      // Phase-offset so the wisps don't pulse in lockstep.
      final t = (steam + i * 0.28) % 1.0;
      final baseX = cx + i * s * 0.11;
      final startY = cupTop - s * 0.02;

      final path = Path()..moveTo(baseX, startY);
      for (double u = 0; u <= 1; u += 0.05) {
        final y = startY - u * s * 0.26 - t * s * 0.06;
        final x =
            baseX + math.sin(u * math.pi * 2.2 + t * math.pi * 2) * s * 0.03;
        path.lineTo(x, y);
      }

      paint.color = color.withValues(
        alpha: math.sin(t * math.pi).clamp(0.0, 1.0) * 0.45,
      );
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

/* ───────────────────────────────  Little H  ─────────────────────────────── */

/// Dough proving in a bowl: a scored boule swells and relaxes, breathing, while
/// flour drifts down around it. Same "vessel + rising" idea as the cup, but the
/// silhouette (shallow bowl + domed loaf) is unmistakably the bakery.
class _ProofPainter extends CustomPainter {
  /// 0..1 — how far the dough has proved.
  final double rise;

  /// 0..1 — phase of the soft wobble across the dome.
  final double wobble;

  /// 0..1 — phase of the falling flour. Negative disables it.
  final double flour;

  final Color color;

  _ProofPainter({
    required this.rise,
    required this.wobble,
    required this.flour,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2;

    final rimY = s * 0.66;
    final halfRim = s * 0.30;

    if (flour >= 0) _paintFlour(canvas, size, s, cx, rimY);

    // The dough grows from a slack lump to a proud, domed boule.
    final grow = 0.62 + 0.38 * rise;
    final domeW = s * 0.46 * grow;
    final domeH = s * 0.30 * grow;

    // A touch of asymmetry that breathes, so it reads as soft dough and not a
    // geometric arch.
    final lean = math.sin(wobble * 2 * math.pi) * s * 0.012;

    final dough = Path()
      ..moveTo(cx - domeW / 2, rimY)
      ..cubicTo(
        cx - domeW / 2 + lean,
        rimY - domeH * 1.25,
        cx + domeW / 2 + lean,
        rimY - domeH * 1.25,
        cx + domeW / 2,
        rimY,
      )
      ..close();

    // Clip to the bowl's mouth so the loaf sits *in* it, not on top of it.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(0, 0, size.width, rimY + s * 0.005),
    );
    canvas.drawPath(
      dough,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.92),
          ],
        ).createShader(
          Rect.fromLTWH(cx - domeW / 2, rimY - domeH * 1.1, domeW, domeH * 1.1),
        ),
    );

    // Baker's scoring — the slashes open up as the loaf proves.
    final scorePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30 + 0.30 * rise)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.016
      ..strokeCap = StrokeCap.round;

    for (int i = -1; i <= 1; i++) {
      final x = cx + i * domeW * 0.20 + lean * 0.6;
      final len = domeH * (0.42 - (i.abs() * 0.12));
      final top = rimY - domeH * 0.72 + (i.abs() * domeH * 0.14);
      canvas.drawLine(
        Offset(x - len * 0.35, top),
        Offset(x + len * 0.35, top + len * 0.55),
        scorePaint,
      );
    }
    canvas.restore();

    // The bowl, drawn over the dough's base so the loaf is seated inside it.
    final bowl = Path()
      ..moveTo(cx - halfRim, rimY)
      ..quadraticBezierTo(cx, rimY + s * 0.34, cx + halfRim, rimY);

    canvas.drawPath(
      bowl,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.024
        ..strokeCap = StrokeCap.round,
    );

    // Rim line.
    canvas.drawLine(
      Offset(cx - halfRim, rimY),
      Offset(cx + halfRim, rimY),
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.024
        ..strokeCap = StrokeCap.round,
    );

    // Bench the bowl sits on.
    final benchY = rimY + s * 0.30;
    canvas.drawLine(
      Offset(cx - s * 0.24, benchY),
      Offset(cx + s * 0.24, benchY),
      Paint()
        ..color = color.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.02
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Flour settling through the air — each speck on its own loop and drift.
  void _paintFlour(Canvas canvas, Size size, double s, double cx, double rimY) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 7; i++) {
      final seed = i / 7;
      final t = (flour + seed) % 1.0;

      final x = cx + math.sin(seed * math.pi * 2 + t * math.pi * 1.6) * s * 0.30;
      final y = s * 0.10 + t * (rimY - s * 0.16);

      // Fade in as it falls, out as it lands.
      final opacity = math.sin(t * math.pi).clamp(0.0, 1.0) * 0.5;
      paint.color = color.withValues(alpha: opacity);

      canvas.drawCircle(
        Offset(x, y),
        s * (0.008 + 0.006 * math.sin(seed * math.pi)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProofPainter old) =>
      old.rise != rise ||
      old.wobble != wobble ||
      old.flour != flour ||
      old.color != color;
}
