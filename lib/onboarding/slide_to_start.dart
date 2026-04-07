import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';

class SlideToStart extends StatefulWidget {
  final VoidCallback onComplete;

  const SlideToStart({required this.onComplete, super.key});

  @override
  State<SlideToStart> createState() => _SlideToStartState();
}

class _SlideToStartState extends State<SlideToStart>
    with TickerProviderStateMixin {
  double _dragValue = 0;

  late final AnimationController _bounceController;
  late final AnimationController _springController;
  late final Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    /// Initial idle bounce
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _bounceAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 10, end: -6), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -6, end: 0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _bounceController, curve: Curves.easeOutBack),
        );

    _springController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        setState(() => _dragValue = _springController.value);
      });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _bounceController.forward();
    });
  }

  void _springBack(double from, double to) {
    _springController.stop();
    _springController.value = from;

    final simulation = SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 380, damping: 22),
      from,
      to,
      0,
    );

    _springController.animateWith(simulation);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _springController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double knobSize = 56;
          final double maxDrag = constraints.maxWidth - knobSize;

          final bool passedHalfway = _dragValue > maxDrag * 0.55;
          final String displayText = passedHalfway
              ? 'Release to savor the moment'
              : 'Fresh brews await';

          final double textOpacity = (1 - (_dragValue / maxDrag)).clamp(
            0.0,
            1.0,
          );

          final double heightProgress = (_dragValue / 40).clamp(0.0, 1.0);

          final double animatedHeight = lerpDouble(
            10.0,
            knobSize,
            heightProgress,
          )!;

          final double bounceOffset = _dragValue == 0
              ? _bounceAnimation.value
              : 0;

          return Container(
            height: knobSize,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                /// Progress fill (correctly aligned)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: _dragValue,
                    height: animatedHeight,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),

                /// Shimmer cafe text
                Center(
                  child: Opacity(
                    opacity: textOpacity,
                    child: ShimmerText(
                      text: displayText,
                      style: theme.textTheme.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),

                /// Draggable knob
                GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragValue = (_dragValue + details.delta.dx).clamp(
                        0,
                        maxDrag,
                      );
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    if (_dragValue > maxDrag * 0.8) {
                      HapticFeedback.mediumImpact();
                      _springBack(_dragValue, maxDrag);
                      widget.onComplete();
                    } else {
                      _springBack(_dragValue, 0);
                    }
                  },
                  child: Transform.translate(
                    offset: Offset(_dragValue + bounceOffset, 0),
                    child: Container(
                      width: knobSize,
                      height: knobSize,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: AnimatedArrows(color: colorScheme.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ✨ Shimmer / glow text
class ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const ShimmerText({required this.text, required this.style, super.key});

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.4),
                Colors.white,
                Colors.white.withValues(alpha: 0.4),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1 + _controller.value * 2, 0),
              end: const Alignment(1, 0),
            ).createShader(bounds);
          },
          child: Text(widget.text, style: widget.style),
        );
      },
    );
  }
}

/// Smooth staggered arrows
class AnimatedArrows extends StatefulWidget {
  final Color color;

  const AnimatedArrows({required this.color, super.key});

  @override
  State<AnimatedArrows> createState() => _AnimatedArrowsState();
}

class _AnimatedArrowsState extends State<AnimatedArrows>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _arrow(double delay, double size) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay, delay + 0.6, curve: Curves.easeOut),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(animation.value * 6, 0),
            child: Icon(Icons.arrow_forward, size: size, color: widget.color),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [_arrow(0.0, 18), const SizedBox(width: 2), _arrow(0.2, 14)],
    );
  }
}
