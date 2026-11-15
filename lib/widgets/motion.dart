import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Small, shared motion pieces. Every one of them stands still when the phone
/// asks for reduced motion (iOS: Accessibility > Motion > Reduce Motion).
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Gives its child a quick pop when [active] turns on (a heart being liked).
class PopOnActivate extends StatefulWidget {
  final bool active;
  final Widget child;
  const PopOnActivate({super.key, required this.active, required this.child});

  @override
  State<PopOnActivate> createState() => _PopOnActivateState();
}

class _PopOnActivateState extends State<PopOnActivate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.45,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.45,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 70,
    ),
  ]).animate(_c);

  @override
  void didUpdateWidget(covariant PopOnActivate old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !reduceMotion(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      // A ring of dots that bursts out as it pops.
      AnimatedBuilder(
        animation: _c,
        builder: (_, _) => _c.isAnimating
            ? CustomPaint(
                size: const Size.square(1),
                painter: _Burst(progress: _c.value),
              )
            : const SizedBox.shrink(),
      ),
      ScaleTransition(scale: _scale, child: widget.child),
    ],
  );
}

class _Burst extends CustomPainter {
  final double progress;
  _Burst({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOut.transform(progress.clamp(0, 1));
    final paint = Paint()
      ..color = const Color(0xFFE5484D).withValues(alpha: (1 - t) * 0.9);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final r = 8 + 14 * t;
      canvas.drawCircle(
        Offset(math.cos(a) * r, math.sin(a) * r),
        2.2 * (1 - t) + 0.4,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Burst old) => old.progress != progress;
}

/// Fades and lifts its child into place the first time it appears in this
/// run of the app. Scrolling back past it doesn't replay it.
class EntranceOnce extends StatefulWidget {
  final String id;
  final int index;
  final Widget child;
  const EntranceOnce({
    super.key,
    required this.id,
    required this.child,
    this.index = 0,
  });

  static final Set<String> _seen = {};

  @override
  State<EntranceOnce> createState() => _EntranceOnceState();
}

class _EntranceOnceState extends State<EntranceOnce>
    with SingleTickerProviderStateMixin {
  late final bool _animate = !EntranceOnce._seen.contains(widget.id);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: _animate ? 0 : 1,
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    EntranceOnce._seen.add(widget.id);
    if (_animate) {
      // A short stagger across a row or section, capped so nothing waits.
      _delay = Timer(
        Duration(milliseconds: 45 * (widget.index % 6)),
        () => mounted ? _c.forward() : null,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) _c.value = 1;
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}

/// "Search 'Iced Caramel Latte'", then another item, sliding up every few
/// seconds, the way Swiggy and Zomato cycle their search hints. Shown only
/// while the field is empty.
class RotatingHint extends StatefulWidget {
  final List<String> words;
  final String fallback;
  final TextStyle style;
  final ValueNotifier<TextEditingValue> controller;

  const RotatingHint({
    super.key,
    required this.words,
    required this.fallback,
    required this.style,
    required this.controller,
  });

  @override
  State<RotatingHint> createState() => _RotatingHintState();
}

class _RotatingHintState extends State<RotatingHint> {
  Timer? _timer;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted || widget.words.length < 2) return;
      if (widget.controller.value.text.isNotEmpty) return;
      setState(() => _i = (_i + 1) % widget.words.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        if (value.text.isNotEmpty) return const SizedBox.shrink();
        final text = widget.words.isEmpty
            ? widget.fallback
            : "Search '${widget.words[_i % widget.words.length]}'";
        // Exactly one line tall, so the next hint can't show beneath the
        // current one while it slides in.
        return ClipRect(
          child: SizedBox(
            height: (widget.style.fontSize ?? 14) * 1.45,
            child: AnimatedSwitcher(
              duration: reduceMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 380),
              transitionBuilder: (child, anim) {
                final incoming = child.key == ValueKey(text);
                return SlideTransition(
                  position:
                      Tween(
                        begin: Offset(0, incoming ? 1 : -1),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: FadeTransition(opacity: anim, child: child),
                );
              },
              child: Align(
                key: ValueKey(text),
                alignment: Alignment.centerLeft,
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: widget.style,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A greeting line with the dish in it, the dish in the brand serif with a
/// few sparkles twinkling around it: "Afternoon slump? *Paneer Grilled
/// Burger* has a crush on you".
class SparkleGreeting extends StatefulWidget {
  final String before;
  final String accent;
  final String after;
  final String subtitle;
  final Color color;

  const SparkleGreeting({
    super.key,
    required this.before,
    required this.accent,
    required this.after,
    required this.subtitle,
    required this.color,
  });

  @override
  State<SparkleGreeting> createState() => _SparkleGreetingState();
}

class _SparkleGreetingState extends State<SparkleGreeting>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _sparkle(double phase, double size) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) {
      final t = (_c.value + phase) % 1.0;
      final v = t < 0.3 ? math.sin(t / 0.3 * math.pi) : 0.0;
      return Opacity(
        opacity: v,
        child: Transform.scale(
          scale: 0.5 + v * 0.6,
          child: Transform.rotate(
            angle: v * 0.6,
            child: Icon(
              PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
              size: size,
              color: widget.color,
            ),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final plain = GoogleFonts.poppins(
      fontSize: 16.sp,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
      height: 1.35,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: plain,
            children: [
              if (widget.before.isNotEmpty) TextSpan(text: widget.before),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Text(
                      widget.accent,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: widget.color,
                        height: 1.2,
                      ),
                    ),
                    Positioned(top: -6, right: -10, child: _sparkle(0, 10.sp)),
                    Positioned(
                      bottom: 0,
                      right: -13,
                      child: _sparkle(0.35, 7.sp),
                    ),
                    Positioned(top: -3, left: -9, child: _sparkle(0.68, 7.sp)),
                  ],
                ),
              ),
              if (widget.after.isNotEmpty) TextSpan(text: widget.after),
            ],
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          widget.subtitle,
          style: GoogleFonts.poppins(fontSize: 12.sp, color: Colors.black38),
        ),
      ],
    );
  }
}
