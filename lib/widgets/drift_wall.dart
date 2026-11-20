import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A tilted wall of photo tiles drifting up and down in columns at different
/// speeds, fading at the edges. Native take on React Bits' DriftWall.
/// Stands still when the phone asks for reduced motion.
class DriftWall extends StatefulWidget {
  final List<String> images; // asset paths
  final int columns;
  final double tileAspect; // width / height
  final double gap;
  final double radius;
  final double tilt; // degrees, pitch
  final double turn; // degrees, yaw
  final double speed; // logical px per second
  final double variance; // 0..1, how much column speeds differ
  final Color background;
  final double dim; // tile opacity

  /// Walls built with this share one clock, so a wall that replaces another
  /// (splash to welcome) carries on from the same frame instead of restarting.
  final bool sharedClock;

  const DriftWall({
    super.key,
    required this.images,
    this.columns = 4,
    this.tileAspect = 0.78,
    this.gap = 10,
    this.radius = 14,
    this.tilt = 14,
    this.turn = -12,
    this.speed = 22,
    this.variance = 0.45,
    this.background = Colors.black,
    this.dim = 0.9,
    this.sharedClock = false,
  });

  static final Stopwatch _clock = Stopwatch();

  @override
  State<DriftWall> createState() => _DriftWallState();
}

class _DriftWallState extends State<DriftWall> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _elapsed = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    if (widget.sharedClock && !DriftWall._clock.isRunning) DriftWall._clock.start();
    _ticker = createTicker(
      (d) => _elapsed.value = widget.sharedClock
          ? DriftWall._clock.elapsedMicroseconds / 1e6
          : d.inMicroseconds / 1e6,
    )..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final p in widget.images) {
      precacheImage(AssetImage(p), context);
    }
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce && _ticker.isActive) _ticker.stop();
    if (!reduce && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  /// Column speed factor, spread evenly but not in order (golden ratio).
  double _factor(int c) => 1 + widget.variance * ((((c * 0.6180339887) + 0.35) % 1) * 2 - 1);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // The wall is drawn larger than the box so the tilt never shows an edge.
        final wallWidth = box.maxWidth * 1.45;
        final colWidth = wallWidth / widget.columns;
        final tileW = colWidth - widget.gap;
        final tileH = tileW / widget.tileAspect;
        final unit = tileH + widget.gap;
        final wallHeight = box.maxHeight * 1.6;

        // Each column holds a rotated slice of the photos.
        final columns = List.generate(widget.columns, (c) {
          final list = [for (var i = 0; i < widget.images.length; i++) widget.images[(i + c * 3) % widget.images.length]];
          return list;
        });

        final wall = ValueListenableBuilder<double>(
          valueListenable: _elapsed,
          builder: (_, t, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              for (var c = 0; c < widget.columns; c++)
                ..._columnTiles(
                  images: columns[c],
                  x: c * colWidth + widget.gap / 2,
                  tileW: tileW,
                  tileH: tileH,
                  unit: unit,
                  wallHeight: wallHeight,
                  // Columns alternate direction and differ in speed.
                  offset: (t * widget.speed * _factor(c) * (c.isEven ? 1 : -1)) + c * unit * 0.37,
                ),
            ],
          ),
        );

        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..rotateX(widget.tilt * math.pi / 180)
          ..rotateY(widget.turn * math.pi / 180);

        return ColoredBox(
          color: widget.background,
          child: ClipRect(
            child: ShaderMask(
              // Dissolve into the background at the edges.
              shaderCallback: (rect) => const RadialGradient(
                center: Alignment(0, -0.1),
                radius: 0.95,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.55, 1],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: OverflowBox(
                maxWidth: wallWidth,
                maxHeight: wallHeight,
                child: Transform(
                  alignment: Alignment.center,
                  transform: transform,
                  child: SizedBox(width: wallWidth, height: wallHeight, child: RepaintBoundary(child: wall)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _columnTiles({
    required List<String> images,
    required double x,
    required double tileW,
    required double tileH,
    required double unit,
    required double wallHeight,
    required double offset,
  }) {
    final loop = images.length * unit;
    final shift = ((offset % loop) + loop) % loop;
    final count = (wallHeight / unit).ceil() + 2;
    return [
      for (var i = 0; i < count; i++)
        Positioned(
          left: x,
          top: i * unit - (shift % unit),
          width: tileW,
          height: tileH,
          child: Opacity(
            opacity: widget.dim,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.radius),
              child: Image.asset(
                images[(i + (shift ~/ unit)) % images.length],
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
    ];
  }
}
